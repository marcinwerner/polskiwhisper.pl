"use client";

import { useState, useEffect, useCallback } from "react";
import { Code2, PenTool, BookOpen, MessageSquare, ChevronLeft, ChevronRight } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { cn } from "@/lib/cn";

const CASES = [
  {
    icon: Code2,
    title: "Programista",
    scenario: "Dyktujesz komentarz w kodzie, piszesz prompt do AI, opisujesz pull request.",
    before: "// TODO: naprawic ten endpoint zeby zwracal prawidlowe dane dla uzytkownikow z polskimi znakami w imieniu",
    after: "// TODO: naprawić ten endpoint żeby zwracał prawidłowe dane dla użytkowników z polskimi znakami w imieniu",
  },
  {
    icon: PenTool,
    title: "Pisarz",
    scenario: "Tworzysz szkic artykułu, odpowiadasz na maile, piszesz posty.",
    before: "trzeba napisac artyukl o nowych trendach w...",
    after: "Trzeba napisać artykuł o nowych trendach w technologii, które zmieniają sposób w jaki pracujemy na co dzień.",
  },
  {
    icon: BookOpen,
    title: "Researcher",
    scenario: "Notatki z PDFa, cytowanie źródeł, streszczenie artykułu.",
    before: "wedlug badan kowalskiego z 2024...",
    after: "Według badań Kowalskiego z 2024 roku, zastosowanie modeli językowych w analizie tekstu zwiększa efektywność o 40%.",
  },
  {
    icon: MessageSquare,
    title: "Każdy",
    scenario: "Szybka odpowiedź na Slacku, wiadomość na Discordzie, komentarz na forum.",
    before: "dzeki za info, sprawdze i...",
    after: "Dzięki za info, sprawdzę i dam znać do końca dnia. Brzmi dobrze, lecimy z tym!",
  },
] as const;

const AUTO_INTERVAL = 6000;

export function UseCases() {
  const [current, setCurrent] = useState(0);
  const [isPaused, setIsPaused] = useState(false);

  const next = useCallback(() => {
    setCurrent((c) => (c + 1) % CASES.length);
  }, []);

  const prev = useCallback(() => {
    setCurrent((c) => (c - 1 + CASES.length) % CASES.length);
  }, []);

  useEffect(() => {
    if (isPaused) return;
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    if (mq.matches) return;

    const id = setInterval(next, AUTO_INTERVAL);
    return () => clearInterval(id);
  }, [isPaused, next]);

  const item = CASES[current];

  return (
    <section id="use-cases" className="py-[var(--spacing-section)] bg-[var(--color-bg-subtle)]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">
            Dla kogo
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Każdy kto pisze dużo po polsku - zyskuje z PolskiWhisper.
          </p>
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
                  "flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors sm:px-4",
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

          {/* Content */}
          <div className="relative mt-6 min-h-[280px]">
            <AnimatePresence mode="wait">
              <motion.div
                key={current}
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -20 }}
                transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
                className="rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-6 sm:p-8"
              >
                <div className="flex items-center gap-3">
                  <item.icon className="h-6 w-6 text-accent" />
                  <h3 className="text-xl font-semibold">{item.title}</h3>
                </div>
                <p className="mt-2 text-sm text-[var(--color-fg-muted)]">
                  {item.scenario}
                </p>

                <div className="mt-6 grid gap-4 sm:grid-cols-2">
                  <div className="rounded-xl bg-[var(--color-bg)] p-4">
                    <p className="text-xs font-medium uppercase tracking-wider text-[var(--color-fg-subtle)]">
                      Klawiatura
                    </p>
                    <p className="mt-2 font-mono text-sm text-[var(--color-fg-muted)] break-words">
                      {item.before}
                    </p>
                  </div>
                  <div className="rounded-xl border border-accent/20 bg-accent-subtle p-4">
                    <p className="text-xs font-medium uppercase tracking-wider text-accent">
                      PolskiWhisper
                    </p>
                    <p className="mt-2 font-mono text-sm break-words">
                      {item.after}
                    </p>
                  </div>
                </div>
              </motion.div>
            </AnimatePresence>

            {/* Navigation arrows */}
            <button
              onClick={prev}
              className="absolute -left-3 top-1/2 -translate-y-1/2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-2 text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)] sm:-left-5"
              aria-label="Poprzedni przykład"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              onClick={next}
              className="absolute -right-3 top-1/2 -translate-y-1/2 rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-2 text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)] sm:-right-5"
              aria-label="Następny przykład"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>

          {/* Dots */}
          <div className="mt-4 flex items-center justify-center gap-2">
            {CASES.map((_, i) => (
              <button
                key={i}
                onClick={() => setCurrent(i)}
                className={cn(
                  "h-2 rounded-full transition-all",
                  i === current
                    ? "w-6 bg-accent"
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
