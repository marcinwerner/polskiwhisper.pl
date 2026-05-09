"use client";

import { WifiOff, ShieldCheck, Code2 } from "lucide-react";
import { motion } from "motion/react";

const POINTS = [
  {
    icon: WifiOff,
    title: "Offline po setupie",
    description:
      "Po pobraniu modelu Whisper Twoje audio nigdy nie opuszcza komputera. Żadnych serwerów, żadnego przetwarzania w chmurze.",
  },
  {
    icon: ShieldCheck,
    title: "Zero telemetrii",
    description:
      "Brak analytics, crash reportów, phone-home. Kod publiczny na GitHub - każdy może audytować co dokładnie aplikacja robi.",
  },
  {
    icon: Code2,
    title: "Open source MIT",
    description:
      "Możesz forknąć, modyfikować, użyć komercyjnie. Pełna transparentność, zero ukrytych kosztów.",
  },
] as const;

export function Privacy() {
  return (
    <section className="py-[var(--spacing-section)] bg-[var(--color-bg-subtle)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">
            Prywatność jako fundament
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            W czasach gdy wszystko trafia do chmury - Twoje słowa zostają u Ciebie.
          </p>
        </div>

        <div className="mt-16 grid gap-8 sm:grid-cols-3">
          {POINTS.map((point, i) => (
            <motion.div
              key={point.title}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-80px" }}
              transition={{
                duration: 0.5,
                delay: i * 0.12,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="group rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-8 transition-colors hover:border-accent/30"
            >
              <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-accent-subtle">
                <point.icon className="h-7 w-7 text-accent" />
              </div>
              <h3 className="mt-5 text-lg font-semibold">{point.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-[var(--color-fg-muted)]">
                {point.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
