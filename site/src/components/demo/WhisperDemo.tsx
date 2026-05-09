"use client";

import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Mail, Mic, Command, Lock } from "lucide-react";
import { cn } from "@/lib/cn";

type Phase =
  | "idle"
  | "hotkey"
  | "recording"
  | "processing"
  | "inserted"
  | "rest";

const SAMPLE_TEXT =
  "Cześć Marto, dzięki za przesłanie raportu. Przejrzałem wszystkie sekcje i mam kilka uwag, które omówię na jutrzejszym callu o dziesiątej.";

const TIMINGS = {
  hotkey: 700,
  recording: 3500,
  processing: 350,
  hold: 4500,
  rest: 1200,
} as const;

export function WhisperDemo() {
  const [phase, setPhase] = useState<Phase>("idle");
  const [insertedText, setInsertedText] = useState("");
  const [bars, setBars] = useState<number[]>(() => new Array(40).fill(0));
  const animFrameRef = useRef<number>(0);
  const phaseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sectionRef = useRef<HTMLElement>(null);
  const startedRef = useRef(false);

  // Start animation when section comes into view (intersection observer)
  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting && !startedRef.current) {
            startedRef.current = true;
            setPhase("hotkey");
          }
        }
      },
      { threshold: 0.4 }
    );

    observer.observe(section);
    return () => observer.disconnect();
  }, []);

  // Phase state machine
  useEffect(() => {
    if (phaseTimerRef.current) clearTimeout(phaseTimerRef.current);

    const reducedMotion =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (reducedMotion) {
      // Static end state for reduced motion
      setPhase("inserted");
      setInsertedText(SAMPLE_TEXT);
      return;
    }

    if (phase === "idle") return;

    if (phase === "hotkey") {
      phaseTimerRef.current = setTimeout(() => setPhase("recording"), TIMINGS.hotkey);
    } else if (phase === "recording") {
      phaseTimerRef.current = setTimeout(
        () => setPhase("processing"),
        TIMINGS.recording
      );
    } else if (phase === "processing") {
      phaseTimerRef.current = setTimeout(() => {
        setInsertedText(SAMPLE_TEXT);
        setPhase("inserted");
      }, TIMINGS.processing);
    } else if (phase === "inserted") {
      phaseTimerRef.current = setTimeout(() => setPhase("rest"), TIMINGS.hold);
    } else if (phase === "rest") {
      phaseTimerRef.current = setTimeout(() => {
        setInsertedText("");
        setPhase("hotkey");
      }, TIMINGS.rest);
    }

    return () => {
      if (phaseTimerRef.current) clearTimeout(phaseTimerRef.current);
    };
  }, [phase]);

  // Animate bars during recording phase (simulated audio levels)
  useEffect(() => {
    if (phase !== "recording") {
      setBars(new Array(40).fill(0));
      return;
    }

    const reducedMotion =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reducedMotion) return;

    let last = performance.now();
    const heights = new Float32Array(40);
    const phases = Array.from({ length: 40 }, () => Math.random() * Math.PI * 2);
    let nextBurst = 0;

    const tick = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      const t = now / 1000;

      // Speech-like bursts
      if (now > nextBurst) {
        const center = Math.floor(Math.random() * 40);
        for (let b = -6; b <= 6; b++) {
          const idx = center + b;
          if (idx >= 0 && idx < 40) {
            const falloff = 1 - Math.abs(b) / 6;
            heights[idx] = Math.max(heights[idx], 0.6 + Math.random() * 0.4 * falloff);
          }
        }
        nextBurst = now + 100 + Math.random() * 200;
      }

      const next = new Array(40);
      for (let i = 0; i < 40; i++) {
        const wave =
          (Math.sin(t * 6 + phases[i]) * 0.3 + Math.sin(t * 11 + phases[i]) * 0.2) +
          0.15;
        const target = Math.max(0.05, Math.min(1, wave + heights[i]));
        const isAttacking = target > heights[i];
        const rate = isAttacking ? 16 : 5;
        heights[i] = heights[i] + (target - heights[i]) * Math.min(1, dt * rate);
        next[i] = heights[i];
      }
      setBars(next);
      animFrameRef.current = requestAnimationFrame(tick);
    };

    animFrameRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(animFrameRef.current);
  }, [phase]);

  return (
    <section
      ref={sectionRef}
      id="demo"
      className="py-[var(--spacing-section)]"
    >
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold sm:text-4xl">
            Tak to wygląda na żywo
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Hotkey, mówisz, tekst pojawia się w aktywnym oknie. Wszystko
            lokalnie, audio nie opuszcza komputera.
          </p>
        </motion.div>

        {/* Mock app window */}
        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.97 }}
          whileInView={{ opacity: 1, y: 0, scale: 1 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.7, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
          className="relative mt-12"
        >
          <div className="overflow-hidden rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)] shadow-2xl">
            {/* Title bar */}
            <div className="flex items-center gap-3 border-b border-[var(--color-border-subtle)] bg-[var(--color-bg-subtle)] px-4 py-3">
              <div className="flex gap-1.5">
                <span className="h-3 w-3 rounded-full bg-[#ff5f57]" />
                <span className="h-3 w-3 rounded-full bg-[#febc2e]" />
                <span className="h-3 w-3 rounded-full bg-[#28c840]" />
              </div>
              <div className="flex flex-1 items-center justify-center gap-2 text-sm text-[var(--color-fg-muted)]">
                <Mail className="h-4 w-4" />
                <span className="font-medium">Nowa wiadomość</span>
              </div>
              <div className="w-12" />
            </div>

            {/* Email-like content */}
            <div className="space-y-3 p-6 sm:p-8 min-h-[280px]">
              <div className="flex items-center gap-3 border-b border-[var(--color-border-subtle)] pb-3">
                <span className="text-sm text-[var(--color-fg-subtle)]">Do:</span>
                <span className="text-sm">marta@example.com</span>
              </div>
              <div className="flex items-center gap-3 border-b border-[var(--color-border-subtle)] pb-3">
                <span className="text-sm text-[var(--color-fg-subtle)]">
                  Temat:
                </span>
                <span className="text-sm">Re: Raport za październik</span>
              </div>

              {/* Cursor + inserted text area */}
              <div className="pt-3">
                <p className="text-base leading-relaxed text-[var(--color-fg)] min-h-[80px]">
                  <AnimatePresence mode="wait">
                    {insertedText ? (
                      <motion.span
                        key="text"
                        initial={{
                          opacity: 0,
                          filter: "blur(8px)",
                          scale: 0.98,
                        }}
                        animate={{
                          opacity: 1,
                          filter: "blur(0px)",
                          scale: 1,
                        }}
                        transition={{
                          duration: 0.4,
                          ease: [0.16, 1, 0.3, 1],
                        }}
                      >
                        {insertedText}
                      </motion.span>
                    ) : (
                      <motion.span
                        key="cursor"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        className="inline-flex items-center"
                      >
                        <span className="inline-block h-5 w-[2px] animate-blink bg-[var(--color-fg)]" />
                      </motion.span>
                    )}
                  </AnimatePresence>
                </p>
              </div>
            </div>
          </div>

          {/* HUD overlay - PolskiWhisper status pill */}
          <div className="pointer-events-none absolute bottom-4 left-1/2 -translate-x-1/2 sm:bottom-6">
            <AnimatePresence mode="wait">
              {(phase === "idle" || phase === "rest") && (
                <motion.div
                  key="idle"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: 10 }}
                  transition={{ duration: 0.25 }}
                  className="flex items-center gap-2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)]/95 px-4 py-2 text-xs font-medium text-[var(--color-fg-muted)] shadow-lg backdrop-blur-md"
                >
                  <Mic className="h-3.5 w-3.5" />
                  <span>Naciśnij</span>
                  <kbd className="flex items-center gap-0.5 rounded bg-[var(--color-bg)] px-1.5 py-0.5 font-mono text-[10px]">
                    <Command className="h-2.5 w-2.5" />
                    <span>⌥</span>
                    <span>S</span>
                  </kbd>
                  <span>aby dyktować</span>
                </motion.div>
              )}

              {phase === "hotkey" && (
                <motion.div
                  key="hotkey"
                  initial={{ opacity: 0, y: 10, scale: 0.9 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  transition={{ duration: 0.2 }}
                  className="flex items-center gap-2 rounded-full border border-accent/40 bg-accent-subtle px-4 py-2 text-xs font-semibold text-accent shadow-lg backdrop-blur-md"
                >
                  <kbd className="flex items-center gap-0.5 rounded bg-accent/20 px-1.5 py-0.5 font-mono text-[10px]">
                    <Command className="h-2.5 w-2.5" />
                    <span>⌥</span>
                    <span>S</span>
                  </kbd>
                  <span>Aktywowane</span>
                </motion.div>
              )}

              {phase === "recording" && (
                <motion.div
                  key="recording"
                  initial={{ opacity: 0, y: 10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  transition={{ duration: 0.25 }}
                  className="flex items-center gap-3 rounded-full border border-accent/40 bg-[var(--color-bg-elevated)]/95 px-4 py-2 shadow-[0_0_24px_oklch(0.55_0.22_18/0.4)] backdrop-blur-md"
                >
                  <span className="relative flex h-2 w-2">
                    <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-75" />
                    <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
                  </span>
                  <span className="text-xs font-semibold text-accent">
                    Słucham...
                  </span>
                  {/* Mini live waveform */}
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

              {phase === "processing" && (
                <motion.div
                  key="processing"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.2 }}
                  className="flex items-center gap-2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)]/95 px-4 py-2 text-xs font-medium text-[var(--color-fg-muted)] shadow-lg backdrop-blur-md"
                >
                  <span className="flex gap-1">
                    <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-accent [animation-delay:0ms]" />
                    <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-accent [animation-delay:150ms]" />
                    <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-accent [animation-delay:300ms]" />
                  </span>
                  <span>Przetwarzam...</span>
                </motion.div>
              )}

              {phase === "inserted" && (
                <motion.div
                  key="inserted"
                  initial={{ opacity: 0, y: 10, scale: 0.9 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                  className="flex items-center gap-2 rounded-full border border-[var(--color-success)]/30 bg-[var(--color-success)]/10 px-4 py-2 text-xs font-semibold text-[var(--color-success)] shadow-lg backdrop-blur-md"
                >
                  <span>✓</span>
                  <span>Wstawione</span>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </motion.div>

        {/* Privacy callout */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="mt-8 flex flex-col items-center gap-3 text-center sm:flex-row sm:justify-center sm:gap-6"
        >
          <div className="flex items-center gap-2 text-sm text-[var(--color-fg-muted)]">
            <Lock className="h-4 w-4 text-accent" />
            <span>Audio nie opuszcza komputera</span>
          </div>
          <span className="hidden text-[var(--color-border)] sm:inline">•</span>
          <div className="flex items-center gap-2 text-sm text-[var(--color-fg-muted)]">
            <span className="text-accent font-mono text-base">~1.5 GB</span>
            <span>model Whisper Large dla najlepszej jakości</span>
          </div>
          <span className="hidden text-[var(--color-border)] sm:inline">•</span>
          <div className="flex items-center gap-2 text-sm text-[var(--color-fg-muted)]">
            <span className="font-mono text-base text-accent">~0.2s</span>
            <span>od końca mowy do tekstu</span>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
