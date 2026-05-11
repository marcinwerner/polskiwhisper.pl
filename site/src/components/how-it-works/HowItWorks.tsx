"use client";

import { Download, Brain, Mic } from "lucide-react";
import { motion } from "motion/react";
import { FEATURES } from "@/lib/flags";

const STEPS = [
  {
    icon: Download,
    number: "01",
    title: "Pobierz aplikację",
    description: FEATURES.WINDOWS_BETA_PUBLIC
      ? "Pobierz PolskiWhisper dla macOS lub Windows. Instalacja zajmuje chwilę."
      : "Pobierz PolskiWhisper dla macOS Apple Silicon. Instalacja zajmuje chwilę.",
  },
  {
    icon: Brain,
    number: "02",
    title: "Pobierz model Whisper",
    description:
      "Jednorazowe pobranie modelu (~1.5 GB). Po tym - pełny offline. Żadnych kont, subskrypcji ani chmury.",
  },
  {
    icon: Mic,
    number: "03",
    title: "Wciśnij hotkey i mów",
    description:
      "Naciśnij skrót klawiszowy, mów po polsku - tekst pojawi się tam gdzie kursor. W dowolnej aplikacji.",
  },
] as const;

export function HowItWorks() {
  return (
    <section id="how-it-works" className="py-[var(--spacing-section)] sm:py-[var(--spacing-section)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">
            Jak to działa
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Trzy kroki do szybszego pisania. Bez komplikacji.
          </p>
        </div>

        <div className="relative mt-16 grid gap-8 sm:grid-cols-3">
          {/* Connector line - desktop only */}
          <div
            className="absolute top-12 left-[16.67%] right-[16.67%] hidden h-px bg-gradient-to-r from-transparent via-[var(--color-border)] to-transparent sm:block"
            aria-hidden="true"
          />

          {STEPS.map((step, i) => (
            <motion.div
              key={step.number}
              initial={{ opacity: 0, y: 32 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-80px" }}
              transition={{
                duration: 0.5,
                delay: i * 0.15,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="relative flex flex-col items-center text-center"
            >
              <div className="relative z-10 flex h-24 w-24 items-center justify-center rounded-2xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)]">
                <step.icon className="h-10 w-10 text-accent" />
              </div>

              <span className="mt-4 text-sm font-medium text-accent">
                {step.number}
              </span>
              <h3 className="mt-2 text-xl font-semibold">{step.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-[var(--color-fg-muted)]">
                {step.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
