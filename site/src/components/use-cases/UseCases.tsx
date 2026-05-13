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

// Per-case typing profile. Każda postać ma własną prędkość + płynność.
// Prędkość = keyboardSpeed (niższe = szybciej). Płynność = jitter range +
// pause frequency/duration + typo rate. Profile dobrane do charakteru postaci.
//
// Target % per case (Marcin's spec):
//   Programista: prędkość 90% / płynność 95% - touch typing pro
//   Pisarz:      prędkość 75% / płynność 70% - doświadczony piszący
//   Researcher:  prędkość 65% / płynność 65% - skupiony, ale dokładny
//   Każdy:       prędkość 55% / płynność 65% - casual hunt-and-peck
const CASES = [
  {
    icon: Code2,
    title: "Programista",
    scenario: "Komentarz w kodzie, prompt do AI, opis pull requesta.",
    texts: [
      "TODO naprawić ten endpoint żeby zwracał prawidłowe dane dla użytkowników z polskimi znakami w imieniu",
      "TODO refactor tego komponentu na server actions zamiast useEffect bo na mobile ładuje się wieki i userzy uciekają",
      "TODO dorzucić middleware rate limiting bo bots zalewają endpoint i wczoraj API padło na trzy godziny w nocy",
      "TODO przepisać ten cron job na queue bo jak fail to nie ma retry i admin musi co rano sprawdzać manualnie",
    ],
    // 90% / 95% - prawie deterministyczne pisanie pro
    keyboardSpeed: 0.42,
    jitterMin: 0.85,
    jitterMax: 1.15,
    pauseEveryMin: 30,
    pauseEveryMax: 50,
    pauseDurationMin: 60,
    pauseDurationMax: 180,
    longPauseProbability: 0.02,
    longPauseDurationMin: 400,
    longPauseDurationMax: 700,
    typoProbability: 0.03,
    typoLeaveUncorrectedRatio: 0.10,
  },
  {
    icon: PenTool,
    title: "Pisarz",
    scenario: "Szkic artykułu, odpowiedź na maile, post na blog.",
    texts: [
      "Trzeba napisać artykuł o nowych trendach w technologii, które zmieniają sposób w jaki pracujemy.",
      "Czytałem dziś o stoickiej filozofii - Marek Aureliusz pisał, że szczęście zależy od jakości myśli.",
      "Książka o produktywności mówi, że godzina deep work warta jest cztery godziny rozproszonej pracy.",
    ],
    // 75% / 70% - płynnie z momentami zastanowienia
    keyboardSpeed: 0.60,
    jitterMin: 0.60,
    jitterMax: 1.40,
    pauseEveryMin: 18,
    pauseEveryMax: 30,
    pauseDurationMin: 100,
    pauseDurationMax: 300,
    longPauseProbability: 0.06,
    longPauseDurationMin: 500,
    longPauseDurationMax: 1000,
    typoProbability: 0.08,
    typoLeaveUncorrectedRatio: 0.20,
  },
  {
    icon: BookOpen,
    title: "Researcher",
    scenario: "Notatki z PDFa, cytowanie źródeł, streszczenie artykułu.",
    texts: [
      "Średnia osoba pisze 40 słów na minutę, mówi 150. Steve Woodmore wypowiedział 637 słów na minutę - rekord Guinnessa z 1990.",
      "Rekord pisania na klawiaturze - Barbara Blackburn, 216 słów na minutę. Średnia rozmowa to 150 słów, więc nawet rekordzistka tylko dogania mowę.",
      "Stenografistka sądowa osiąga 360 słów na minutę na specjalnej klawiaturze. Mowa potoczna - 150. Dyktowanie głosem zostawia każdą klawiaturę w tyle.",
    ],
    // 65% / 65% - skupiony charakter, umiarkowane pauzy myślowe
    keyboardSpeed: 0.72,
    jitterMin: 0.55,
    jitterMax: 1.50,
    pauseEveryMin: 15,
    pauseEveryMax: 25,
    pauseDurationMin: 120,
    pauseDurationMax: 380,
    longPauseProbability: 0.08,
    longPauseDurationMin: 600,
    longPauseDurationMax: 1100,
    typoProbability: 0.10,
    typoLeaveUncorrectedRatio: 0.25,
  },
  {
    icon: MessageSquare,
    title: "Każdy",
    scenario: "Slack, Discord, komentarze, wiadomości.",
    texts: [
      "Pisanie głosem to nawyk - pierwszy tydzień dziwnie, drugi już automatyczny, trzeci zastanawiasz się jak żyłeś bez tego.",
      "Czytałem że ludzie używający AI codziennie pracują krócej i robią więcej. Może warto?",
    ],
    // 55% / 65% - casual; różny charakter od Researchera widać przez wolniejszą prędkość
    keyboardSpeed: 0.84,
    jitterMin: 0.55,
    jitterMax: 1.50,
    pauseEveryMin: 15,
    pauseEveryMax: 25,
    pauseDurationMin: 120,
    pauseDurationMax: 380,
    longPauseProbability: 0.08,
    longPauseDurationMin: 600,
    longPauseDurationMax: 1100,
    typoProbability: 0.10,
    typoLeaveUncorrectedRatio: 0.25,
  },
] as const;

// Voice timings - tuned for snappy demo (40% faster than baseline conversational pace)
const SPEECH_WPM = 224; // ~40% faster than 140 baseline (voice text appears quickly)
const SPEECH_MS_PER_WORD = 60_000 / SPEECH_WPM; // ~268ms
const PROCESSING_MS = 420; // 40% faster than 700ms baseline
const KEYBOARD_SPEED_RATIO = 3; // Stanford 2016: speech is 3x faster
const KEYBOARD_GLOBAL_SPEEDUP = 0.8; // additional 20% faster on keyboard
const POST_FINISH_HOLD = 2800; // ms to hold final state before next case

// Typo backspace delay - mechanika identyczna dla wszystkich postaci
const TYPO_BACKSPACE_DELAY = [60, 140] as const; // ms

function pickTimings(text: string, kbSpeed: number) {
  const words = text.split(/\s+/).filter(Boolean).length;
  const voiceSpeakingMs = words * SPEECH_MS_PER_WORD;
  const voiceTotalMs = voiceSpeakingMs + PROCESSING_MS;
  // Keyboard total: voice * Stanford ratio * global 20% speedup * per-case speed factor
  const keyboardTotalMs =
    voiceTotalMs * KEYBOARD_SPEED_RATIO * KEYBOARD_GLOBAL_SPEEDUP * kbSpeed;
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

// Startujemy od "Każdy" (index 3, d1) - bo to najbardziej przystępny tekst dla pierwszego kontaktu.
// Auto-cycle dalej w naturalnej kolejności: 3 → 0 → 1 → 2 → 3 → ...
const INITIAL_CASE_INDEX = 3;

export function UseCases() {
  const [current, setCurrent] = useState(INITIAL_CASE_INDEX);
  // visitCount[i] = ile razy case `i` zostało aktywowane. Tekst do pokazania = texts[(visit-1) % texts.length].
  // Initial case startuje z 1 (initial mount), reszta z 0.
  const [visitCount, setVisitCount] = useState<Record<number, number>>(() => {
    const init: Record<number, number> = {};
    CASES.forEach((_, i) => {
      init[i] = 0;
    });
    init[INITIAL_CASE_INDEX] = 1;
    return init;
  });
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
  // Ref synchronicznie trackuje ostatni cel advanceTo - dedup rapid clicks (np. dwa kliknięcia tabu zanim render się zakończy).
  const lastAdvancedRef = useRef(INITIAL_CASE_INDEX);

  const advanceTo = useCallback((nextIndex: number) => {
    if (lastAdvancedRef.current === nextIndex) return; // no-op gdy ta sama kategoria
    lastAdvancedRef.current = nextIndex;
    setVisitCount((vc) => ({
      ...vc,
      [nextIndex]: (vc[nextIndex] ?? 0) + 1,
    }));
    setCurrent(nextIndex);
  }, []);

  const next = useCallback(() => {
    advanceTo((lastAdvancedRef.current + 1) % CASES.length);
  }, [advanceTo]);

  const prev = useCallback(() => {
    advanceTo((lastAdvancedRef.current - 1 + CASES.length) % CASES.length);
  }, [advanceTo]);

  // Single scene effect - all timers scheduled together, cleanup on case change
  useEffect(() => {
    const item = CASES[current];
    // Wybierz tekst na podstawie liczby odwiedzin tej kategorii w tej sesji.
    // visitNum=1 → texts[0], =2 → texts[1], wraps around tablicy.
    const visitNum = visitCount[current] ?? 1;
    const textIdx = (visitNum - 1) % item.texts.length;
    const text = item.texts[textIdx];
    const { voiceSpeakingMs, voiceTotalMs, keyboardTotalMs, baseCharDelayMs } =
      pickTimings(text, item.keyboardSpeed);

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
      setKeyboardText(text);
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

        // Keyboard typing - natural with jitter, pauses, typos (sometimes corrected, sometimes left)
        // Each action is a single atomic step - displayed text accumulates as user sees it.
        type Action =
          | { type: "append"; ch: string; delay: number }
          | { type: "backspace"; delay: number };

        const actions: Action[] = [];
        let charsUntilPause = randInt(item.pauseEveryMin, item.pauseEveryMax);
        let wordChars = 0;
        let typosLeftCount = 0;
        const maxLeftTypos = 1;

        for (let i = 0; i < text.length; i++) {
          const ch = text[i];
          const isWordBoundary = ch === " " || ch === "," || ch === "." || ch === "-";

          // Per-char delay with per-case jitter (wąski = pro typist, szeroki = casual)
          const jitter = randFloat(item.jitterMin, item.jitterMax);
          let delay = baseCharDelayMs * jitter;

          // Occasional thinking pauses (some short, rare longer "real" thinking)
          charsUntilPause--;
          if (charsUntilPause <= 0 && i > 3 && i < text.length - 3) {
            if (Math.random() < item.longPauseProbability) {
              delay += randFloat(item.longPauseDurationMin, item.longPauseDurationMax);
            } else {
              delay += randFloat(item.pauseDurationMin, item.pauseDurationMax);
            }
            charsUntilPause = randInt(item.pauseEveryMin, item.pauseEveryMax);
          }

          // Maybe inject a typo at start of a word
          if (
            !isWordBoundary &&
            wordChars === 0 &&
            i > 1 &&
            i < text.length - 5 &&
            Math.random() < item.typoProbability
          ) {
            const wrong = pickTypo(ch);
            if (wrong && wrong !== ch) {
              const leaveIt =
                typosLeftCount < maxLeftTypos &&
                Math.random() < item.typoLeaveUncorrectedRatio;

              if (leaveIt) {
                // Type wrong char, leave it (no backspace, just advance to next)
                actions.push({ type: "append", ch: wrong, delay });
                typosLeftCount++;
                if (isWordBoundary) wordChars = 0;
                else wordChars++;
                continue;
              } else {
                // Type wrong, brief pause, backspace, brief pause, type correct
                actions.push({ type: "append", ch: wrong, delay });
                actions.push({
                  type: "backspace",
                  delay: randFloat(TYPO_BACKSPACE_DELAY[0], TYPO_BACKSPACE_DELAY[1]),
                });
                actions.push({
                  type: "append",
                  ch,
                  delay: randFloat(80, 200),
                });
                if (isWordBoundary) wordChars = 0;
                else wordChars++;
                continue;
              }
            }
          }

          actions.push({ type: "append", ch, delay });

          if (isWordBoundary) wordChars = 0;
          else wordChars++;
        }

        // Execute action sequence - functional setState so left-typos persist
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
            if (a.type === "append") {
              setKeyboardText((prev) => prev + a.ch);
            } else if (a.type === "backspace") {
              setKeyboardText((prev) => prev.slice(0, -1));
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
  }, [current, visitCount]);

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
  // Tekst aktualnie wyświetlany - z tablicy texts wg liczby odwiedzin tej kategorii.
  const currentVisitNum = visitCount[current] ?? 1;
  const currentTextIdx = (currentVisitNum - 1) % item.texts.length;
  const currentText = item.texts[currentTextIdx];
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
                onClick={() => advanceTo(i)}
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

          {/* Scenario header - reserved fixed height to prevent shift */}
          <div className="mt-8 text-center">
            <div className="relative h-7">
              <AnimatePresence mode="wait">
                <motion.div
                  key={current}
                  initial={{ opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  transition={{ duration: 0.3 }}
                  className="absolute inset-0 flex items-center justify-center gap-3"
                >
                  <item.icon className="h-5 w-5 text-accent" />
                  <h3 className="text-xl font-semibold">{item.title}</h3>
                </motion.div>
              </AnimatePresence>
            </div>
            <div className="relative mt-2 h-5">
              <AnimatePresence mode="wait">
                <motion.p
                  key={current}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.2 }}
                  className="absolute inset-0 text-sm text-[var(--color-fg-muted)]"
                >
                  {item.scenario}
                </motion.p>
              </AnimatePresence>
            </div>
          </div>

          {/* Race stage: keyboard | hotkey | whisper */}
          <div className="relative mt-8">
            <div className="grid items-stretch gap-3 md:grid-cols-[1fr_auto_1fr] md:gap-4">
              {/* Keyboard window */}
              <KeyboardWindow
                text={keyboardText}
                fullText={currentText}
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
                text={currentText}
                shown={voiceShown}
                elapsed={voiceElapsed}
                voiceFinal={voiceFinalTimeRef.current}
                bars={voiceVisualizer}
                phase={phase}
                started={phase !== "idle"}
              />
            </div>

            {/* Result badge - reserved fixed height to prevent shift */}
            <div className="mt-6 flex h-12 items-center justify-center">
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
                onClick={() => advanceTo(i)}
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
      <div className="mt-4 flex-1 min-h-[180px] flex flex-col">
        <AnimatePresence mode="wait">
          {/* Recording HUD pill - same style as WhisperDemo */}
          {isListening && (
            <motion.div
              key="listening"
              initial={{ opacity: 0, y: 10, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              transition={{ duration: 0.25 }}
              className="m-auto flex items-center gap-3 rounded-full border border-accent/40 bg-[var(--color-bg-elevated)]/95 px-4 py-2 shadow-[0_0_24px_oklch(0.55_0.22_18/0.4)] backdrop-blur-md"
            >
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
              </span>
              <span className="text-xs font-semibold text-accent">
                Słucham...
              </span>
              <div className="flex h-5 items-center gap-[2px]">
                {bars.slice(0, 18).map((v, i) => (
                  <div
                    key={i}
                    className="w-[2px] rounded-full bg-accent"
                    style={{
                      height: `${Math.max(2, v * 18)}px`,
                      opacity: 0.7 + v * 0.3,
                    }}
                  />
                ))}
              </div>
            </motion.div>
          )}

          {/* Processing HUD pill - same style */}
          {isProcessing && (
            <motion.div
              key="processing"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="m-auto flex items-center gap-2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)]/95 px-4 py-2 text-xs font-medium text-[var(--color-fg-muted)] shadow-lg backdrop-blur-md"
            >
              <span className="flex gap-1">
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-accent [animation-delay:0ms]" />
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-accent [animation-delay:150ms]" />
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-accent [animation-delay:300ms]" />
              </span>
              <span>Przetwarzam...</span>
            </motion.div>
          )}

          {/* Result text + brief Wstawione pill */}
          {shown && (
            <motion.div
              key="text"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.3 }}
              className="flex w-full flex-col items-center gap-3"
            >
              <motion.p
                initial={{ opacity: 0, scale: 0.95, filter: "blur(8px)" }}
                animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
                transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                className="font-mono text-sm leading-relaxed sm:text-base"
              >
                {text}
              </motion.p>
            </motion.div>
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
    running: "Pisanie i słuchanie",
    processing: "Przetwarzam transkrypcję",
    "voice-done": "Whisper gotowy, klawiatura pisze",
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
          "inline-flex h-9 items-center gap-2 whitespace-nowrap rounded-full border px-4 text-sm",
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
