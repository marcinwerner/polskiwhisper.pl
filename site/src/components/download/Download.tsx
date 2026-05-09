"use client";

import { useState } from "react";
import { Apple, MonitorDot, ExternalLink, CheckCircle2 } from "lucide-react";
import { motion, AnimatePresence } from "motion/react";
import { cn } from "@/lib/cn";

type Platform = "macos" | "windows";

const PLATFORMS = {
  macos: {
    icon: Apple,
    label: "macOS",
    version: "v0.1.5",
    status: "Stabilna",
    statusColor: "text-[var(--color-success)]",
    downloadUrl:
      "https://github.com/marcinwerner/polskiwhisper.pl/releases/latest",
    downloadLabel: "Pobierz .dmg",
    requirements: [
      "macOS 14 Sonoma lub nowszy",
      "Apple Silicon (M1/M2/M3/M4)",
      "~2 GB wolnego miejsca",
      "Mikrofon",
    ],
    quickStart: [
      "Otwórz DMG i przeciągnij do Aplikacji",
      'Pierwsze uruchomienie: kliknij prawym → "Otwórz"',
      "Wybierz hotkey i pobierz model Whisper (~1.5 GB)",
    ],
  },
  windows: {
    icon: MonitorDot,
    label: "Windows",
    version: "v0.1.0-preview",
    status: "Pre-release",
    statusColor: "text-accent",
    downloadUrl:
      "https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/win-v0.1.0-preview",
    downloadLabel: "Pobierz .zip (113 MB)",
    requirements: [
      "Windows 10 1809+ lub Windows 11",
      "~4 GB wolnego RAM",
      "~500 MB miejsca na dysku",
      "Mikrofon",
      "Opcjonalnie: GPU z DirectX 12",
    ],
    quickStart: [
      "Rozpakuj ZIP gdziekolwiek",
      "Uruchom PolskiWhisper.exe",
      'SmartScreen: kliknij "Więcej informacji" → "Uruchom mimo to"',
    ],
  },
} as const;

export function Download() {
  const [platform, setPlatform] = useState<Platform>("macos");
  const data = PLATFORMS[platform];

  return (
    <section
      id="download"
      className="py-[var(--spacing-section)] bg-[var(--color-bg-subtle)]"
    >
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">Pobierz</h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            Darmowa, na zawsze. Bez rejestracji, bez konta, bez subskrypcji.
          </p>
        </div>

        {/* Platform tabs */}
        <div className="mt-10 flex items-center justify-center gap-2 rounded-xl bg-[var(--color-bg)] p-1.5">
          {(["macos", "windows"] as const).map((p) => (
            <button
              key={p}
              onClick={() => setPlatform(p)}
              className={cn(
                "relative flex-1 rounded-lg px-6 py-3 text-sm font-medium transition-colors",
                platform === p
                  ? "text-[var(--color-fg)]"
                  : "text-[var(--color-fg-muted)] hover:text-[var(--color-fg)]"
              )}
            >
              {platform === p && (
                <motion.div
                  layoutId="download-tab"
                  className="absolute inset-0 rounded-lg bg-[var(--color-bg-elevated)] border border-[var(--color-border-subtle)]"
                  transition={{ type: "spring", bounce: 0.15, duration: 0.5 }}
                />
              )}
              <span className="relative flex items-center justify-center gap-2">
                {p === "macos" ? (
                  <Apple className="h-4 w-4" />
                ) : (
                  <MonitorDot className="h-4 w-4" />
                )}
                {PLATFORMS[p].label}
              </span>
            </button>
          ))}
        </div>

        {/* Platform content */}
        <AnimatePresence mode="wait">
          <motion.div
            key={platform}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.2 }}
            className="mt-6 rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-6 sm:p-8"
          >
            <div className="flex items-center justify-between">
              <div>
                <span className="text-2xl font-bold">{data.version}</span>
                <span className={cn("ml-3 text-sm font-medium", data.statusColor)}>
                  {data.status}
                </span>
              </div>
            </div>

            <a
              href={data.downloadUrl}
              className="mt-6 flex h-14 w-full items-center justify-center gap-2 rounded-xl bg-accent px-6 text-base font-semibold text-[var(--color-accent-fg)] shadow-[var(--shadow-glow)] transition-all hover:bg-accent-hover active:scale-[0.98]"
            >
              <data.icon className="h-5 w-5" />
              {data.downloadLabel}
              <ExternalLink className="ml-1 h-4 w-4 opacity-60" />
            </a>

            {/* Requirements */}
            <div className="mt-8">
              <h3 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-fg-subtle)]">
                Wymagania systemowe
              </h3>
              <ul className="mt-3 space-y-2">
                {data.requirements.map((req) => (
                  <li
                    key={req}
                    className="flex items-start gap-2 text-sm text-[var(--color-fg-muted)]"
                  >
                    <span className="mt-0.5 text-accent">•</span>
                    {req}
                  </li>
                ))}
              </ul>
            </div>

            {/* Quick start */}
            <div className="mt-8">
              <h3 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-fg-subtle)]">
                Po pobraniu
              </h3>
              <ol className="mt-3 space-y-2">
                {data.quickStart.map((step, i) => (
                  <li
                    key={step}
                    className="flex items-start gap-3 text-sm text-[var(--color-fg-muted)]"
                  >
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                    {step}
                  </li>
                ))}
              </ol>
            </div>
          </motion.div>
        </AnimatePresence>
      </div>
    </section>
  );
}
