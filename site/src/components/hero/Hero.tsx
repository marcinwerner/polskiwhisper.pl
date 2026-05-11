"use client";

import { Apple, MonitorDot, ArrowDown } from "lucide-react";
import { motion, useScroll, useTransform } from "motion/react";
import { useRef } from "react";
import { Waveform } from "./Waveform";
import { FEATURES } from "@/lib/flags";

// Direct asset URLs - GitHub counts each as a download
const MACOS_RELEASE_URL =
  "https://github.com/marcinwerner/polskiwhisper.pl/releases/download/v0.1.5/PolskiWhisper-0.1.5.dmg";
const WINDOWS_RELEASE_URL =
  "https://github.com/marcinwerner/polskiwhisper.pl/releases/download/win-v0.1.0-preview/PolskiWhisper-0.1.0-preview-win-x64.zip";
const GITHUB_URL = "https://github.com/marcinwerner/polskiwhisper.pl";

export function Hero() {
  const sectionRef = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ["start start", "end start"],
  });

  // Parallax: waveform scales down + fades, content moves slower
  const waveformScale = useTransform(scrollYProgress, [0, 1], [1, 1.2]);
  const waveformOpacity = useTransform(scrollYProgress, [0, 0.6], [1, 0]);
  const contentY = useTransform(scrollYProgress, [0, 1], [0, 80]);
  const contentOpacity = useTransform(scrollYProgress, [0, 0.7], [1, 0]);

  return (
    <section
      ref={sectionRef}
      className="relative min-h-dvh flex items-center justify-center overflow-hidden"
    >
      {/* Animated gradient mesh */}
      <div className="gradient-mesh" aria-hidden="true" />

      {/* Waveform - parallax */}
      <motion.div
        style={{ scale: waveformScale, opacity: waveformOpacity }}
        className="absolute inset-0"
      >
        <Waveform />
      </motion.div>

      {/* Bottom fade to bg */}
      <div className="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-b from-transparent to-[var(--color-bg)] pointer-events-none" />

      {/* Content - parallax up */}
      <motion.div
        style={{ y: contentY, opacity: contentOpacity }}
        className="relative z-10 mx-auto max-w-5xl px-4 py-24 text-center sm:px-6 lg:px-8"
      >
        {/* Pre-headline pill */}
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          className="mx-auto mb-6 inline-flex items-center gap-2 rounded-full border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)]/80 px-4 py-1.5 text-xs font-medium text-[var(--color-fg-muted)] backdrop-blur-md"
        >
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
          </span>
          {FEATURES.WINDOWS_BETA_PUBLIC
            ? "Wersja 0.1.5 dostępna - macOS i Windows"
            : "Dostępne dla macOS Apple Silicon"}
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 30, filter: "blur(10px)" }}
          animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
          transition={{
            duration: 0.8,
            ease: [0.16, 1, 0.3, 1],
            delay: 0.1,
          }}
          className="text-[clamp(2.8rem,10vw,6.5rem)] font-extrabold leading-[0.95] tracking-[-0.04em]"
        >
          <span className="block">Mówisz.</span>
          <motion.span
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.4, ease: [0.16, 1, 0.3, 1] }}
            className="block bg-gradient-to-br from-accent via-accent-light to-accent bg-clip-text text-transparent"
          >
            Piszesz.
          </motion.span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.6, ease: [0.16, 1, 0.3, 1] }}
          className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-[var(--color-fg-muted)] sm:text-xl"
        >
          {FEATURES.WINDOWS_BETA_PUBLIC
            ? "Darmowa aplikacja do dyktowania w macOS i Windows."
            : "Darmowa aplikacja do dyktowania w macOS."}
          <br className="hidden sm:block" />
          Działa offline. Twoje audio nigdy nie opuszcza komputera.
        </motion.p>

        {/* CTAs */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 1.0, ease: [0.16, 1, 0.3, 1] }}
          className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center"
        >
          <motion.a
            href={MACOS_RELEASE_URL}
            download
            whileHover={{ scale: 1.04, transition: { duration: 0.2 } }}
            whileTap={{ scale: 0.97 }}
            className="group relative inline-flex h-14 w-full items-center justify-center gap-2.5 overflow-hidden rounded-xl bg-accent px-8 text-base font-semibold text-[var(--color-accent-fg)] shadow-[var(--shadow-glow)] transition-shadow hover:shadow-[0_0_60px_oklch(0.55_0.22_18/0.5)] sm:w-auto"
          >
            <span className="absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-white/20 to-transparent transition-transform duration-700 group-hover:translate-x-full" />
            <Apple className="h-5 w-5" />
            Pobierz dla macOS
          </motion.a>
          {FEATURES.WINDOWS_BETA_PUBLIC && (
            <motion.a
              href={WINDOWS_RELEASE_URL}
              download
              whileHover={{ scale: 1.04, transition: { duration: 0.2 } }}
              whileTap={{ scale: 0.97 }}
              className="inline-flex h-14 w-full items-center justify-center gap-2.5 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)]/80 px-8 text-base font-semibold backdrop-blur-md transition-colors hover:border-accent/50 hover:bg-[var(--color-bg-subtle)] sm:w-auto"
            >
              <MonitorDot className="h-5 w-5" />
              Pobierz dla Windows
              <span className="ml-1 rounded-md bg-accent-subtle px-1.5 py-0.5 text-xs font-medium text-accent">
                beta
              </span>
            </motion.a>
          )}
        </motion.div>

        {!FEATURES.WINDOWS_BETA_PUBLIC && (
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6, delay: 1.15 }}
            className="mt-3 inline-flex items-center gap-1.5 text-xs text-[var(--color-fg-subtle)]"
          >
            <MonitorDot className="h-3 w-3" />
            Wkrótce na Windows
          </motion.p>
        )}

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 1.2 }}
          className="mt-8 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 text-sm text-[var(--color-fg-subtle)]"
        >
          <span>✓ MIT</span>
          <span>✓ Open source</span>
          <span>✓ Zero telemetrii</span>
        </motion.div>

        <motion.a
          href={GITHUB_URL}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 1.3 }}
          className="mt-4 inline-flex items-center gap-1.5 text-sm text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)]"
          target="_blank"
          rel="noopener noreferrer"
        >
          <svg
            className="h-4 w-4"
            viewBox="0 0 16 16"
            fill="currentColor"
            aria-hidden="true"
          >
            <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
          </svg>
          GitHub
        </motion.a>
      </motion.div>

      {/* Scroll indicator */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.6, delay: 1.6 }}
        style={{ opacity: contentOpacity }}
        className="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 text-xs text-[var(--color-fg-subtle)]"
      >
        <span className="uppercase tracking-wider">Przewiń</span>
        <motion.div
          animate={{ y: [0, 6, 0] }}
          transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut" }}
        >
          <ArrowDown className="h-4 w-4" />
        </motion.div>
      </motion.div>
    </section>
  );
}
