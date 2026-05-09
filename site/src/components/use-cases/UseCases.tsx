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

const AUTO_INTERVAL = 9000;
const KEYBOARD_CHAR_DELAY = 60; // ms per char - simulates 40 WPM-ish
const VOICE_REVEAL_DELAY = 1800; // delay before voice version appears
const POST_REVEAL_PAUSE = 4500; // hold both before next slide

export function UseCases() {
  const [current, setCurrent] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [keyboardText, setKeyboardText] = useState("");
  const [voiceShown, setVoiceShown] = useState(false);
  const [phase, setPhase] = useState<"typing" | "voice" | "done">("typing");
  const charIndexRef = useRef(0);
  const phaseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const charTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const next = useCallback(() => {
    setCurrent((c) => (c + 1) % CASES.length);
  }, []);

  const prev = useCallback(() => {
    setCurrent((c) => (c - 1 + CASES.length) % CASES.length);
  }, []);

  // Drive the typing/voice animation for the current case
  useEffect(() => {
    if (phaseTimerRef.current) clearTimeout(phaseTimerRef.current);
    if (charTimerRef.current) clearTimeout(charTimerRef.current);

    const item = CASES[current];
    setKeyboardText("");
    setVoiceShown(false);
    setPhase("typing");
    charIndexRef.current = 0;

    const reducedMotion =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (reducedMotion) {
      setKeyboardText(item.text);
      setVoiceShown(true);
      setPhase("done");
      return;
    }

    function typeChar() {
      const i = charIndexRef.current;
      if (i < item.text.length) {
        setKeyboardText(item.text.slice(0, i + 1));
        charIndexRef.current = i + 1;
        charTimerRef.current = setTimeout(typeChar, KEYBOARD_CHAR_DELAY);
      } else {
        // Trigger voice reveal after delay
        phaseTimerRef.current = setTimeout(() => {
          setVoiceShown(true);
          setPhase("voice");
          phaseTimerRef.current = setTimeout(() => {
            setPhase("done");
          }, POST_REVEAL_PAUSE);
        }, VOICE_REVEAL_DELAY);
      }
    }

    // Small delay before typing starts
    phaseTimerRef.current = setTimeout(typeChar, 400);

    return () => {
      if (phaseTimerRef.current) clearTimeout(phaseTimerRef.current);
      if (charTimerRef.current) clearTimeout(charTimerRef.current);
    };
  }, [current]);

  // Auto-advance carousel after done phase
  useEffect(() => {
    if (isPaused) return;
    if (phase !== "done") return;
    const id = setTimeout(next, AUTO_INTERVAL - VOICE_REVEAL_DELAY);
    return () => clearTimeout(id);
  }, [phase, isPaused, next]);

  const item = CASES[current];

  return (
    <section
      id="use-cases"
      className="py-[var(--spacing-section)] bg-[var(--color-bg-subtle)]"
    >
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
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

          {/* Two parallel windows */}
          <div className="relative mt-8">
            <div className="grid gap-4 sm:gap-6 md:grid-cols-2">
              {/* Keyboard window */}
              <KeyboardWindow text={keyboardText} fullText={item.text} />

              {/* Voice window */}
              <VoiceWindow text={item.text} shown={voiceShown} />
            </div>

            {/* Comparison badge - centered between */}
            <div className="mt-6 flex items-center justify-center">
              <ComparisonBadge phase={phase} />
            </div>

            {/* Navigation arrows */}
            <button
              onClick={prev}
              className="absolute -left-3 top-[120px] -translate-y-1/2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-2 text-[var(--color-fg-muted)] transition-all hover:scale-110 hover:text-[var(--color-fg)] sm:-left-5 md:hidden"
              aria-label="Poprzedni przykład"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              onClick={next}
              className="absolute -right-3 top-[120px] -translate-y-1/2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-2 text-[var(--color-fg-muted)] transition-all hover:scale-110 hover:text-[var(--color-fg)] sm:-right-5 md:hidden"
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

function KeyboardWindow({ text, fullText }: { text: string; fullText: string }) {
  const isComplete = text.length >= fullText.length;
  const wpm = isComplete ? 40 : null;

  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      className="rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-5 sm:p-6"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Keyboard className="h-4 w-4 text-[var(--color-fg-subtle)]" />
          <p className="text-xs font-medium uppercase tracking-wider text-[var(--color-fg-subtle)]">
            Klawiatura
          </p>
        </div>
        {wpm && (
          <motion.span
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="font-mono text-xs text-[var(--color-fg-subtle)] tabular-nums"
          >
            ~40 WPM
          </motion.span>
        )}
      </div>
      <div className="mt-4 min-h-[140px]">
        <p className="font-mono text-sm leading-relaxed sm:text-base">
          {text}
          <span
            className={cn(
              "ml-0.5 inline-block w-[2px] -translate-y-[2px] bg-[var(--color-fg)]",
              isComplete
                ? "h-4 animate-pulse opacity-50"
                : "h-4 animate-blink"
            )}
          />
        </p>
      </div>
    </motion.div>
  );
}

function VoiceWindow({ text, shown }: { text: string; shown: boolean }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
      className="relative overflow-hidden rounded-2xl border border-accent/30 bg-accent-subtle p-5 sm:p-6"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Mic className="h-4 w-4 text-accent" />
          <p className="text-xs font-medium uppercase tracking-wider text-accent">
            PolskiWhisper
          </p>
        </div>
        {shown && (
          <motion.span
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="font-mono text-xs text-accent tabular-nums"
          >
            ~130 WPM
          </motion.span>
        )}
      </div>
      <div className="mt-4 min-h-[140px]">
        <AnimatePresence>
          {shown && (
            <motion.p
              initial={{ opacity: 0, scale: 0.95, filter: "blur(8px)" }}
              animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
              transition={{
                duration: 0.5,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="font-mono text-sm leading-relaxed sm:text-base"
            >
              {text}
            </motion.p>
          )}
        </AnimatePresence>
      </div>

      {/* Burst effect when voice appears */}
      <AnimatePresence>
        {shown && (
          <motion.div
            key="burst"
            className="pointer-events-none absolute inset-0"
            initial={{ opacity: 0 }}
            animate={{
              opacity: [0, 0.6, 0],
              background: [
                "radial-gradient(circle at 50% 50%, transparent 0%, transparent 100%)",
                "radial-gradient(circle at 50% 50%, var(--color-accent) 0%, transparent 70%)",
                "radial-gradient(circle at 50% 50%, transparent 0%, transparent 100%)",
              ],
            }}
            transition={{ duration: 0.8 }}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

function ComparisonBadge({ phase }: { phase: "typing" | "voice" | "done" }) {
  const labels = {
    typing: "Pisanie na klawiaturze...",
    voice: "Powiedziane głosem - cały tekst od razu",
    done: "3× szybciej. Bez literówek.",
  };

  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={phase}
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -6 }}
        transition={{ duration: 0.3 }}
        className={cn(
          "inline-flex items-center gap-2 rounded-full border px-4 py-2 text-sm",
          phase === "done"
            ? "border-accent/40 bg-accent-subtle text-accent font-semibold"
            : "border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] text-[var(--color-fg-muted)]"
        )}
      >
        {phase === "voice" && (
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
          </span>
        )}
        {labels[phase]}
      </motion.div>
    </AnimatePresence>
  );
}
