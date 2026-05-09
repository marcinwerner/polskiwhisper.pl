"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import {
  Code2,
  PenTool,
  BookOpen,
  MessageSquare,
  ChevronLeft,
  ChevronRight,
  Keyboard,
  Mic,
  Command,
} from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { cn } from "@/lib/cn";

const CASES = [
  {
    icon: Code2,
    title: "Programista",
    scenario: "Komentarz w kodzie, prompt do AI, opis pull requesta.",
    text: "TODO naprawić ten endpoint żeby zwracał prawidłowe dane dla użytkowników z polskimi znakami w imieniu",
  },
  {
    icon: PenTool,
    title: "Pisarz",
    scenario: "Szkic artykułu, odpowiedź na maile, post na blog.",
    text: "Trzeba napisać artykuł o nowych trendach w technologii, które zmieniają sposób w jaki pracujemy na co dzień.",
  },
  {
    icon: BookOpen,
    title: "Researcher",
    scenario: "Notatki z PDFa, cytowanie źródeł, streszczenie artykułu.",
    text: "Według badań Kowalskiego z 2024 roku, zastosowanie modeli językowych w analizie tekstu zwiększa efektywność o 40%.",
  },
  {
    icon: MessageSquare,
    title: "Każdy",
    scenario: "Slack, Discord, komentarze, wiadomości.",
    text: "Dzięki za info, sprawdzę i dam znać do końca dnia. Brzmi dobrze, lecimy z tym.",
  },
] as const;

// Realistic timings: speech at ~140 WPM, Whisper processing on M1 ~600-900ms
const SPEECH_WPM = 140; // average natural speech rate
const SPEECH_MS_PER_WORD = 60_000 / SPEECH_WPM; // ~428ms
const PROCESSING_MS = 700; // realistic Whisper-on-M1 transcription delay
const KEYBOARD_SPEED_RATIO = 3; // Stanford 2016: speech is 3x faster
const POST_FINISH_HOLD = 2800; // ms to hold final state before next case

// Natural typing variability
const KEYBOARD_JITTER_MIN = 0.6;
const KEYBOARD_JITTER_MAX = 1.5;
const PAUSE_EVERY_MIN_CHARS = 8;
const PAUSE_EVERY_MAX_CHARS = 18;
const PAUSE_DURATION_MIN = 180;
const PAUSE_DURATION_MAX = 480;
const TYPO_PROBABILITY = 0.08; // 8% of words have a typo to correct
const TYPO_BACKSPACE_DELAY = [60, 120] as const; // ms

function pickTimings(text: string) {
  const words = text.split(/\s+/).filter(Boolean).length;
  const voiceSpeakingMs = words * SPEECH_MS_PER_WORD;
  const voiceTotalMs = voiceSpeakingMs + PROCESSING_MS;
  const keyboardTotalMs = voiceTotalMs * KEYBOARD_SPEED_RATIO;
  const baseCharDelayMs = keyboardTotalMs / Math.max(1, text.length);
  return { voiceSpeakingMs, voiceTotalMs, keyboardTotalMs, baseCharDelayMs };
}

function randInt(min: number, max: number) {
  return min + Math.floor(Math.random() * (max - min + 1));
}

function randFloat(min: number, max: number) {
  return min + Math.random() * (max - min);
}

const TYPO_NEIGHBORS: Record<string, string> = {
  a: "sq", b: "vn", c: "xv", d: "fs", e: "rw", f: "gd", g: "hf", h: "jg",
  i: "uo", j: "kh", k: "lj", l: "k", m: "n", n: "mb", o: "ip", p: "ol",
  q: "wa", r: "te", s: "da", t: "ry", u: "iy", v: "cb", w: "qe", x: "zc",
  y: "tu", z: "x", "ą": "ao", "ć": "cv", "ę": "ew", "ł": "kl", "ń": "nm",
  "ó": "po", "ś": "sd", "ź": "xz", "ż": "zx",
};

function pickTypo(correctChar: string): string | null {
  const lower = correctChar.toLowerCase();
  const neighbors = TYPO_NEIGHBORS[lower];
  if (!neighbors) return null;
  const wrong = neighbors[randInt(0, neighbors.length - 1)];
  return correctChar === correctChar.toUpperCase() ? wrong.toUpperCase() : wrong;
}

type Phase =
  | "idle"
  | "running" // both timers ticking, keyboard typing, hotkey pressed, whisper listening
  | "voice-released" // hotkey just released, brief gap before text
  | "voice-done" // whisper text shown, voice clock stopped, keyboard still typing
  | "all-done" // both finished, comparison shown
  | "next-pending"; // brief rest before next case

export function UseCases() {
  const [current, setCurrent] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [phase, setPhase] = useState<Phase>("idle");
  const [keyboardText, setKeyboardText] = useState("");
  const [voiceShown, setVoiceShown] = useState(false);
  const [keyboardElapsed, setKeyboardElapsed] = useState(0);
  const [voiceElapsed, setVoiceElapsed] = useState(0);
  const [voiceVisualizer, setVoiceVisualizer] = useState<number[]>(
    () => new Array(20).fill(0)
  );

  const sectionStartRef = useRef<number>(0);
  const charIndexRef = useRef(0);
  const voiceFinalTimeRef = useRef(0);
  const keyboardFinalTimeRef = useRef(0);
  const tickRafRef = useRef<number>(0);
  const charTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const phaseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const visualizerRafRef = useRef<number>(0);

  const next = useCallback(() => {
    setCurrent((c) => (c + 1) % CASES.length);
  }, []);

  const prev = useCallback(() => {
    setCurrent((c) => (c - 1 + CASES.length) % CASES.length);
  }, []);

  // Single scene effect - all timers scheduled together, cleanup on case change
  useEffect(() => {
    const item = CASES[current];
    const { voiceSpeakingMs, voiceTotalMs, keyboardTotalMs, baseCharDelayMs } =
      pickTimings(item.text);

    // Reset all state for new case
    setKeyboardText("");
    setVoiceShown(false);
    setKeyboardElapsed(0);
    setVoiceElapsed(0);
    setVoiceVisualizer(new Array(20).fill(0));
    charIndexRef.current = 0;
    voiceFinalTimeRef.current = 0;
    keyboardFinalTimeRef.current = 0;

    const reducedMotion =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (reducedMotion) {
      setKeyboardText(item.text);
      setVoiceShown(true);
      voiceFinalTimeRef.current = voiceTotalMs / 1000;
      keyboardFinalTimeRef.current = keyboardTotalMs / 1000;
      setKeyboardElapsed(keyboardFinalTimeRef.current);
      setVoiceElapsed(voiceFinalTimeRef.current);
      setPhase("all-done");
      return;
    }

    setPhase("idle");
    const localTimers: ReturnType<typeof setTimeout>[] = [];

    // Pre-roll: 600ms then race starts
    localTimers.push(
      setTimeout(() => {
        sectionStartRef.current = performance.now();
        setPhase("running");

        // Master tick - both clocks run together
        function tick() {
          const now = performance.now();
          const elapsedSec = (now - sectionStartRef.current) / 1000;
          setKeyboardElapsed(elapsedSec);
          // voice clock keeps ticking only until hotkey released
          if (voiceFinalTimeRef.current === 0) {
            setVoiceElapsed(elapsedSec);
          }
          tickRafRef.current = requestAnimationFrame(tick);
        }
        tickRafRef.current = requestAnimationFrame(tick);

        // Voice visualizer animation
        const vphases = Array.from({ length: 20 }, () => Math.random() * Math.PI * 2);
        let nextBurst = 0;
        const heights = new Float32Array(20);
        let lastFrame = performance.now();

        function visualizerTick() {
          const now = performance.now();
          const dt = Math.min(0.05, (now - lastFrame) / 1000);
          lastFrame = now;
          const t = now / 1000;

          if (now > nextBurst) {
            const center = Math.floor(Math.random() * 20);
            for (let b = -4; b <= 4; b++) {
              const idx = center + b;
              if (idx >= 0 && idx < 20) {
                const falloff = 1 - Math.abs(b) / 4;
                heights[idx] = Math.max(
                  heights[idx],
                  0.5 + Math.random() * 0.5 * falloff
                );
              }
            }
            nextBurst = now + 80 + Math.random() * 160;
          }

          const next = new Array(20);
          for (let i = 0; i < 20; i++) {
            const wave =
              Math.sin(t * 7 + vphases[i]) * 0.25 +
              Math.sin(t * 12 + vphases[i]) * 0.15 +
              0.1;
            const target = Math.max(0.04, Math.min(1, wave + heights[i]));
            const isAttacking = target > heights[i];
            const rate = isAttacking ? 18 : 5;
            heights[i] =
              heights[i] + (target - heights[i]) * Math.min(1, dt * rate);
            next[i] = heights[i];
          }
          setVoiceVisualizer(next);
          visualizerRafRef.current = requestAnimationFrame(visualizerTick);
        }
        visualizerRafRef.current = requestAnimationFrame(visualizerTick);

        // Keyboard typing - natural with jitter, pauses, occasional typos
        // Plan: build a sequence of "actions" upfront for the full text
        type Action =
          | { type: "char"; ch: string; delay: number }
          | { type: "typo"; wrong: string; delay: number }
          | { type: "backspace"; delay: number };

        const actions: Action[] = [];
        let charsUntilPause = randInt(PAUSE_EVERY_MIN_CHARS, PAUSE_EVERY_MAX_CHARS);
        let wordChars = 0;

        for (let i = 0; i < item.text.length; i++) {
          const ch = item.text[i];
          const isWordBoundary = ch === " " || ch === "," || ch === "." || ch === "-";

          // Per-char delay with jitter
          const jitter = randFloat(KEYBOARD_JITTER_MIN, KEYBOARD_JITTER_MAX);
          let delay = baseCharDelayMs * jitter;

          // Insert occasional thinking pause before this char
          charsUntilPause--;
          if (charsUntilPause <= 0 && i > 3 && i < item.text.length - 3) {
            delay += randFloat(PAUSE_DURATION_MIN, PAUSE_DURATION_MAX);
            charsUntilPause = randInt(PAUSE_EVERY_MIN_CHARS, PAUSE_EVERY_MAX_CHARS);
          }

          // Maybe inject a typo at start of word
          if (
            !isWordBoundary &&
            wordChars === 0 &&
            i > 0 &&
            i < item.text.length - 4 &&
            Math.random() < TYPO_PROBABILITY
          ) {
            const wrong = pickTypo(ch);
            if (wrong && wrong !== ch) {
              actions.push({ type: "typo", wrong, delay });
              actions.push({
                type: "backspace",
                delay: randFloat(TYPO_BACKSPACE_DELAY[0], TYPO_BACKSPACE_DELAY[1]),
              });
              // The correct char follows with a small recovery delay
              delay = randFloat(80, 160);
            }
          }

          actions.push({ type: "char", ch, delay });

          if (isWordBoundary) wordChars = 0;
          else wordChars++;
        }

        // Execute action sequence
        let actionIdx = 0;
        function runNextAction() {
          if (actionIdx >= actions.length) {
            keyboardFinalTimeRef.current =
              (performance.now() - sectionStartRef.current) / 1000;
            setKeyboardElapsed(keyboardFinalTimeRef.current);
            cancelAnimationFrame(tickRafRef.current);
            setPhase("all-done");
            return;
          }
          const a = actions[actionIdx];
          charTimerRef.current = setTimeout(() => {
            if (a.type === "char") {
              charIndexRef.current += 1;
              setKeyboardText(item.text.slice(0, charIndexRef.current));
            } else if (a.type === "typo") {
              // Show current text + wrong char appended
              setKeyboardText(
                item.text.slice(0, charIndexRef.current) + a.wrong
              );
            } else if (a.type === "backspace") {
              // Remove the typo char (back to confirmed text)
              setKeyboardText(item.text.slice(0, charIndexRef.current));
            }
            actionIdx++;
            runNextAction();
          }, a.delay);
        }
        runNextAction();

        // Hotkey release after voice finishes speaking - processing starts
        localTimers.push(
          setTimeout(() => {
            cancelAnimationFrame(visualizerRafRef.current);
            setVoiceVisualizer(new Array(20).fill(0));
            setPhase("voice-released");

            // After processing delay, voice text appears - voice clock freezes
            localTimers.push(
              setTimeout(() => {
                const elapsedSec =
                  (performance.now() - sectionStartRef.current) / 1000;
                voiceFinalTimeRef.current = elapsedSec;
                setVoiceElapsed(elapsedSec);
                setVoiceShown(true);
                setPhase("voice-done");
              }, PROCESSING_MS)
            );
          }, voiceSpeakingMs)
        );
      }, 600)
    );

    return () => {
      localTimers.forEach((t) => clearTimeout(t));
      if (charTimerRef.current) clearTimeout(charTimerRef.current);
      cancelAnimationFrame(tickRafRef.current);
      cancelAnimationFrame(visualizerRafRef.current);
    };
  }, [current]);

  // Auto-advance after all-done
  useEffect(() => {
    if (phase !== "all-done") return;
    if (isPaused) return;
    phaseTimerRef.current = setTimeout(next, POST_FINISH_HOLD);
    return () => {
      if (phaseTimerRef.current) clearTimeout(phaseTimerRef.current);
    };
  }, [phase, isPaused, next]);

  const item = CASES[current];
  const hotkeyPressed = phase === "running";
  const voiceReleasing = phase === "voice-released";
  const isComplete = phase === "all-done";
  const speedRatio = isComplete && voiceFinalTimeRef.current > 0
    ? keyboardFinalTimeRef.current / voiceFinalTimeRef.current
    : 0;

  return (
    <section
      id="use-cases"
      className="py-[var(--spacing-section)] bg-[var(--color-bg-subtle)]"
    >
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
            className="text-3xl font-bold sm:text-4xl"
          >
            Dla kogo
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.5, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
            className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]"
          >
            Każdy kto pisze dużo po polsku - zyskuje z PolskiWhisper.
          </motion.p>
        </div>

        <div
          className="mt-12"
          onMouseEnter={() => setIsPaused(true)}
          onMouseLeave={() => setIsPaused(false)}
        >
          {/* Tabs */}
          <div className="flex items-center justify-center gap-2 sm:gap-4">
            {CASES.map((c, i) => (
              <button
                key={c.title}
                onClick={() => setCurrent(i)}
                className={cn(
                  "flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium transition-all sm:px-4",
                  i === current
                    ? "bg-accent-subtle text-accent"
                    : "text-[var(--color-fg-muted)] hover:text-[var(--color-fg)]"
                )}
              >
                <c.icon className="h-4 w-4" />
                <span className="hidden sm:inline">{c.title}</span>
              </button>
            ))}
          </div>

          {/* Scenario header */}
          <div className="mt-8 text-center">
            <AnimatePresence mode="wait">
              <motion.div
                key={current}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.3 }}
                className="flex items-center justify-center gap-3"
              >
                <item.icon className="h-5 w-5 text-accent" />
                <h3 className="text-xl font-semibold">{item.title}</h3>
              </motion.div>
            </AnimatePresence>
            <p className="mt-2 text-sm text-[var(--color-fg-muted)]">
              {item.scenario}
            </p>
          </div>

          {/* Race stage: keyboard | hotkey | whisper */}
          <div className="relative mt-8">
            <div className="grid items-stretch gap-3 md:grid-cols-[1fr_auto_1fr] md:gap-4">
              {/* Keyboard window */}
              <KeyboardWindow
                text={keyboardText}
                fullText={item.text}
                elapsed={keyboardElapsed}
                isComplete={isComplete}
                started={phase !== "idle"}
              />

              {/* Center: hotkey indicator */}
              <CenterStage
                hotkeyPressed={hotkeyPressed}
                voiceReleasing={voiceReleasing}
                voiceShown={voiceShown}
              />

              {/* Whisper window */}
              <VoiceWindow
                text={item.text}
                shown={voiceShown}
                elapsed={voiceElapsed}
                voiceFinal={voiceFinalTimeRef.current}
                bars={voiceVisualizer}
                phase={phase}
                started={phase !== "idle"}
              />
            </div>

            {/* Result badge */}
            <div className="mt-6 flex items-center justify-center">
              <ResultBadge
                isComplete={isComplete}
                speedRatio={speedRatio}
                phase={phase}
              />
            </div>

            {/* Mobile arrows */}
            <button
              onClick={prev}
              className="absolute -left-2 top-[170px] -translate-y-1/2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-2 text-[var(--color-fg-muted)] transition-all hover:scale-110 hover:text-[var(--color-fg)] sm:-left-3 md:hidden"
              aria-label="Poprzedni przykład"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              onClick={next}
              className="absolute -right-2 top-[170px] -translate-y-1/2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-2 text-[var(--color-fg-muted)] transition-all hover:scale-110 hover:text-[var(--color-fg)] sm:-right-3 md:hidden"
              aria-label="Następny przykład"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>

          {/* Dots */}
          <div className="mt-8 flex items-center justify-center gap-2">
            {CASES.map((_, i) => (
              <button
                key={i}
                onClick={() => setCurrent(i)}
                className={cn(
                  "h-2 rounded-full transition-all",
                  i === current
                    ? "w-8 bg-accent"
                    : "w-2 bg-[var(--color-border)] hover:bg-[var(--color-fg-subtle)]"
                )}
                aria-label={`Przejdź do przykładu ${i + 1}`}
              />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function formatTime(seconds: number) {
  return seconds.toFixed(1) + "s";
}

function KeyboardWindow({
  text,
  fullText,
  elapsed,
  isComplete,
  started,
}: {
  text: string;
  fullText: string;
  elapsed: number;
  isComplete: boolean;
  started: boolean;
}) {
  const cursorActive = started && text.length < fullText.length;

  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      className="flex flex-col rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-5 sm:p-6"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Keyboard className="h-4 w-4 text-[var(--color-fg-subtle)]" />
          <p className="text-xs font-medium uppercase tracking-wider text-[var(--color-fg-subtle)]">
            Klawiatura
          </p>
        </div>
        <div
          className={cn(
            "flex items-center gap-1.5 rounded-md px-2 py-1 font-mono text-xs tabular-nums transition-colors",
            isComplete
              ? "bg-[var(--color-bg-subtle)] text-[var(--color-fg-muted)]"
              : started
                ? "bg-[var(--color-bg-subtle)] text-[var(--color-fg)]"
                : "text-[var(--color-fg-subtle)]"
          )}
        >
          <span
            className={cn(
              "h-1.5 w-1.5 rounded-full",
              cursorActive ? "bg-[var(--color-fg-muted)] animate-pulse" : "bg-[var(--color-border)]"
            )}
          />
          {formatTime(elapsed)}
        </div>
      </div>
      <div className="mt-4 flex-1 min-h-[180px]">
        <p className="font-mono text-sm leading-relaxed sm:text-base">
          {text}
          {cursorActive && (
            <span className="ml-0.5 inline-block h-4 w-[2px] -translate-y-[2px] animate-blink bg-[var(--color-fg)]" />
          )}
        </p>
      </div>
    </motion.div>
  );
}

function VoiceWindow({
  text,
  shown,
  elapsed,
  voiceFinal,
  bars,
  phase,
  started,
}: {
  text: string;
  shown: boolean;
  elapsed: number;
  voiceFinal: number;
  bars: number[];
  phase: Phase;
  started: boolean;
}) {
  // Display: live elapsed during running, frozen voiceFinal once done
  const displayedTime = shown ? voiceFinal : elapsed;
  const isListening = phase === "running";
  const isProcessing = phase === "voice-released";

  return (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      className="relative flex flex-col overflow-hidden rounded-2xl border border-accent/30 bg-accent-subtle p-5 sm:p-6"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Mic className="h-4 w-4 text-accent" />
          <p className="text-xs font-medium uppercase tracking-wider text-accent">
            PolskiWhisper
          </p>
        </div>
        <div
          className={cn(
            "flex items-center gap-1.5 rounded-md px-2 py-1 font-mono text-xs tabular-nums transition-colors",
            shown
              ? "bg-accent/20 text-accent font-semibold"
              : started
                ? "bg-accent/10 text-accent"
                : "text-[var(--color-fg-subtle)]"
          )}
        >
          {isListening && (
            <span className="relative flex h-1.5 w-1.5">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-75" />
              <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-accent" />
            </span>
          )}
          {!isListening && !shown && started && (
            <span className="h-1.5 w-1.5 rounded-full bg-accent/60" />
          )}
          {shown && <span className="text-accent">✓</span>}
          {formatTime(displayedTime)}
        </div>
      </div>
      <div className="mt-4 flex-1 min-h-[180px]">
        {/* Listening visualizer */}
        <AnimatePresence>
          {isListening && (
            <motion.div
              key="listening"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex h-full flex-col items-center justify-center gap-3"
            >
              <div className="flex h-12 items-center gap-[3px]">
                {bars.map((v, i) => (
                  <div
                    key={i}
                    className="w-[3px] rounded-full bg-accent"
                    style={{
                      height: `${Math.max(3, v * 44)}px`,
                      opacity: 0.7 + v * 0.3,
                    }}
                  />
                ))}
              </div>
              <p className="text-xs font-medium text-accent">Słucham...</p>
            </motion.div>
          )}

          {isProcessing && (
            <motion.div
              key="processing"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex h-full flex-col items-center justify-center gap-3"
            >
              <span className="flex gap-1.5">
                <span className="h-2 w-2 animate-pulse rounded-full bg-accent [animation-delay:0ms]" />
                <span className="h-2 w-2 animate-pulse rounded-full bg-accent [animation-delay:150ms]" />
                <span className="h-2 w-2 animate-pulse rounded-full bg-accent [animation-delay:300ms]" />
              </span>
              <p className="text-xs font-medium text-accent">Przetwarzam...</p>
            </motion.div>
          )}

          {shown && (
            <motion.p
              key="text"
              initial={{ opacity: 0, scale: 0.95, filter: "blur(8px)" }}
              animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
              transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
              className="font-mono text-sm leading-relaxed sm:text-base"
            >
              {text}
            </motion.p>
          )}
        </AnimatePresence>
      </div>

      {/* Burst flash when text appears */}
      <AnimatePresence>
        {shown && (
          <motion.div
            key="burst"
            className="pointer-events-none absolute inset-0"
            initial={{ opacity: 0 }}
            animate={{
              opacity: [0, 0.5, 0],
              background: [
                "radial-gradient(circle at 50% 50%, transparent 0%, transparent 100%)",
                "radial-gradient(circle at 50% 50%, var(--color-accent) 0%, transparent 70%)",
                "radial-gradient(circle at 50% 50%, transparent 0%, transparent 100%)",
              ],
            }}
            transition={{ duration: 0.7 }}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

function CenterStage({
  hotkeyPressed,
  voiceReleasing,
  voiceShown,
}: {
  hotkeyPressed: boolean;
  voiceReleasing: boolean;
  voiceShown: boolean;
}) {
  // Hotkey states: pressed (red glow), releasing (transition), released (normal)
  const status = hotkeyPressed
    ? "pressed"
    : voiceReleasing || voiceShown
      ? "released"
      : "idle";

  return (
    <div className="flex flex-row items-center justify-center gap-3 py-2 md:flex-col md:py-0 md:px-2">
      {/* Hotkey button */}
      <motion.div
        animate={{
          scale: status === "pressed" ? 0.95 : 1,
        }}
        transition={{ type: "spring", stiffness: 400, damping: 30 }}
        className={cn(
          "relative flex items-center gap-1 rounded-xl border-2 px-3 py-2 font-mono text-sm font-bold transition-all",
          status === "pressed"
            ? "border-accent bg-accent text-[var(--color-accent-fg)] shadow-[0_0_24px_oklch(0.55_0.22_18/0.6)] translate-y-[1px]"
            : "border-[var(--color-border)] bg-[var(--color-bg-elevated)] text-[var(--color-fg)] shadow-md"
        )}
      >
        <Command className="h-3.5 w-3.5" />
        <span>⌥</span>
        <span>S</span>
        {status === "pressed" && (
          <motion.span
            className="absolute -inset-2 -z-10 rounded-2xl bg-accent/40 blur-md"
            animate={{ opacity: [0.5, 0.8, 0.5] }}
            transition={{ duration: 0.8, repeat: Infinity }}
          />
        )}
      </motion.div>

      {/* State label below */}
      <AnimatePresence mode="wait">
        <motion.span
          key={status}
          initial={{ opacity: 0, y: -4 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 4 }}
          transition={{ duration: 0.2 }}
          className={cn(
            "hidden text-[10px] font-medium uppercase tracking-wider md:block",
            status === "pressed" ? "text-accent" : "text-[var(--color-fg-subtle)]"
          )}
        >
          {status === "pressed"
            ? "wciśnięty"
            : status === "released"
              ? "puszczony"
              : "gotowy"}
        </motion.span>
      </AnimatePresence>
    </div>
  );
}

function ResultBadge({
  isComplete,
  speedRatio,
  phase,
}: {
  isComplete: boolean;
  speedRatio: number;
  phase: Phase;
}) {
  const status = isComplete
    ? "done"
    : phase === "voice-done"
      ? "voice-done"
      : phase === "voice-released"
        ? "processing"
        : phase === "running"
          ? "running"
          : "idle";

  const labels: Record<typeof status, string> = {
    idle: " ",
    running: "Klawiatura pisze, PolskiWhisper słucha...",
    processing: "Hotkey puszczony - przetwarzam...",
    "voice-done": "PolskiWhisper gotowy. Klawiatura wciąż pisze...",
    done: speedRatio
      ? `${speedRatio.toFixed(1)}× szybciej. Bez literówek.`
      : "Bez literówek.",
  };

  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={status}
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -6 }}
        transition={{ duration: 0.3 }}
        className={cn(
          "inline-flex min-h-[36px] items-center gap-2 rounded-full border px-4 py-2 text-sm",
          status === "done"
            ? "border-accent/40 bg-accent-subtle text-accent font-semibold"
            : "border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] text-[var(--color-fg-muted)]"
        )}
      >
        {status === "running" && (
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
          </span>
        )}
        {labels[status]}
      </motion.div>
    </AnimatePresence>
  );
}
