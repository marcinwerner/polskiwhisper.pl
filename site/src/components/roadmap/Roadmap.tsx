"use client";

import { motion } from "motion/react";
import { cn } from "@/lib/cn";
import { FEATURES } from "@/lib/flags";

type MilestoneStatus = "done" | "current" | "planned";
type Milestone = {
  version: string;
  label: string;
  status: MilestoneStatus;
  windows?: boolean;
};

const ALL_MILESTONES: readonly Milestone[] = [
  {
    version: "v0.1.5",
    label: "macOS Apple Silicon - stable",
    status: "done",
  },
  {
    version: "v0.2.0",
    label: "macOS - rozszerzenia i ustawienia",
    status: "current",
  },
  {
    version: "v0.1.0 beta",
    label: "Windows beta - gotowa do testów",
    status: "done",
    windows: true,
  },
  {
    version: "v0.3.0",
    label: "Windows pełne UI",
    status: "current",
    windows: true,
  },
  {
    version: "v1.0.0",
    label: "Stabilna wersja 1.0",
    status: "planned",
  },
] as const;

const MILESTONES = ALL_MILESTONES.filter(
  (m) => FEATURES.WINDOWS_BETA_PUBLIC || !m.windows
);

export function Roadmap() {
  return (
    <section id="roadmap" className="py-[var(--spacing-section)]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">Roadmapa</h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Co jest teraz i co planujemy dalej.
          </p>
        </div>

        <div className="relative mt-16">
          {/* Timeline line */}
          <div
            className="absolute left-5 top-0 bottom-0 w-px bg-[var(--color-border)] sm:left-1/2"
            aria-hidden="true"
          />

          <div className="space-y-12">
            {MILESTONES.map((m, i) => (
              <motion.div
                key={m.version}
                initial={{ opacity: 0, x: i % 2 === 0 ? -24 : 24 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true, margin: "-60px" }}
                transition={{
                  duration: 0.5,
                  delay: i * 0.1,
                  ease: [0.16, 1, 0.3, 1],
                }}
                className={cn(
                  "relative flex items-start gap-4 sm:gap-0",
                  i % 2 === 0 ? "sm:flex-row" : "sm:flex-row-reverse"
                )}
              >
                {/* Dot */}
                <div className="absolute left-5 flex -translate-x-1/2 sm:left-1/2">
                  <div
                    className={cn(
                      "h-3 w-3 rounded-full border-2",
                      m.status === "done" &&
                        "border-[var(--color-success)] bg-[var(--color-success)]",
                      m.status === "current" &&
                        "border-accent bg-accent animate-pulse",
                      m.status === "planned" &&
                        "border-[var(--color-border)] bg-[var(--color-bg)]"
                    )}
                  />
                </div>

                {/* Content */}
                <div
                  className={cn(
                    "ml-12 rounded-xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-5 sm:ml-0 sm:w-[calc(50%-2rem)]",
                    i % 2 === 0 ? "sm:mr-auto sm:text-right" : "sm:ml-auto"
                  )}
                >
                  <div className="flex items-center gap-2 sm:justify-start">
                    {i % 2 === 0 && (
                      <span className="hidden sm:block flex-1" />
                    )}
                    <span className="text-lg font-bold">{m.version}</span>
                    {m.status === "done" && (
                      <span className="rounded-md bg-[var(--color-success)]/15 px-2 py-0.5 text-xs font-medium text-[var(--color-success)]">
                        ✓
                      </span>
                    )}
                    {m.status === "current" && (
                      <span className="rounded-md bg-accent-subtle px-2 py-0.5 text-xs font-medium text-accent">
                        w toku
                      </span>
                    )}
                  </div>
                  <p className="mt-1 text-sm text-[var(--color-fg-muted)]">
                    {m.label}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
