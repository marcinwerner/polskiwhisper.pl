import { Apple, MonitorDot } from "lucide-react";
import { Waveform } from "./Waveform";
import { Typewriter } from "./Typewriter";

const MACOS_RELEASE_URL =
  "https://github.com/marcinwerner/polskiwhisper.pl/releases/latest";
const WINDOWS_RELEASE_URL =
  "https://github.com/marcinwerner/polskiwhisper.pl/releases/tag/win-v0.1.0-preview";
const GITHUB_URL = "https://github.com/marcinwerner/polskiwhisper.pl";

export function Hero() {
  return (
    <section className="relative min-h-dvh flex items-center justify-center overflow-hidden">
      <Waveform />

      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-[var(--color-bg)]" />

      <div className="relative z-10 mx-auto max-w-5xl px-4 py-24 text-center sm:px-6 lg:px-8">
        <h1
          className="text-[clamp(2.8rem,10vw,5.96rem)] font-extrabold leading-[0.95] tracking-[-0.04em]"
        >
          <span className="block">Mówisz.</span>
          <span className="block text-accent">Piszesz.</span>
        </h1>

        <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-[var(--color-fg-muted)] sm:text-xl">
          Darmowa aplikacja do dyktowania w macOS i Windows.
          <br className="hidden sm:block" />
          Działa offline. Twoje audio nigdy nie opuszcza komputera.
        </p>

        <div className="mx-auto mt-8 max-w-md rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] px-6 py-4">
          <p className="text-sm text-[var(--color-fg-subtle)]">
            Naciśnij hotkey i mów...
          </p>
          <p className="mt-1 text-lg font-medium">
            <Typewriter />
          </p>
        </div>

        <div className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
          <a
            href={MACOS_RELEASE_URL}
            className="inline-flex h-14 w-full items-center justify-center gap-2.5 rounded-xl bg-accent px-8 text-base font-semibold text-[var(--color-accent-fg)] shadow-[var(--shadow-glow)] transition-all hover:bg-accent-hover hover:shadow-[0_0_48px_oklch(0.55_0.22_18/0.35)] active:scale-[0.98] sm:w-auto"
          >
            <Apple className="h-5 w-5" />
            Pobierz dla macOS
          </a>
          <a
            href={WINDOWS_RELEASE_URL}
            className="inline-flex h-14 w-full items-center justify-center gap-2.5 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)] px-8 text-base font-semibold transition-all hover:border-accent/50 hover:bg-[var(--color-bg-subtle)] active:scale-[0.98] sm:w-auto"
          >
            <MonitorDot className="h-5 w-5" />
            Pobierz dla Windows
            <span className="ml-1 rounded-md bg-accent-subtle px-1.5 py-0.5 text-xs font-medium text-accent">
              preview
            </span>
          </a>
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 text-sm text-[var(--color-fg-subtle)]">
          <span>✓ MIT</span>
          <span>✓ Open source</span>
          <span>✓ Zero telemetrii</span>
        </div>

        <a
          href={GITHUB_URL}
          className="mt-4 inline-flex items-center gap-1.5 text-sm text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)]"
          target="_blank"
          rel="noopener noreferrer"
        >
          <svg className="h-4 w-4" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
            <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
          </svg>
          GitHub
        </a>
      </div>
    </section>
  );
}
