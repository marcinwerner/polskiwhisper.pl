"use client";

import { Bug, HeartHandshake } from "lucide-react";

function GithubIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
  );
}
import { motion } from "motion/react";

const LINKS = [
  {
    icon: GithubIcon,
    title: "Otwarty kod, otwarte issues",
    description: "Cały kod jest publiczny. Przeglądaj, forkuj, kontrybuuj.",
    href: "https://github.com/marcinwerner/polskiwhisper.pl",
    label: "GitHub",
  },
  {
    icon: Bug,
    title: "Coś nie działa?",
    description: "Otwórz issue na GitHub. Możesz pisać po polsku.",
    href: "https://github.com/marcinwerner/polskiwhisper.pl/issues/new",
    label: "Zgłoś",
  },
  {
    icon: HeartHandshake,
    title: "Chcesz pomóc?",
    description: "Przeczytaj wytyczne dla kontrybutorów. Każdy wkład się liczy.",
    href: "https://github.com/marcinwerner/polskiwhisper.pl/blob/main/CONTRIBUTING.md",
    label: "Współpraca",
  },
] as const;

export function Community() {
  return (
    <section className="py-[var(--spacing-section)]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold sm:text-4xl">Społeczność</h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--color-fg-muted)]">
            PolskiWhisper to projekt otwarty - zbudowany dla polskiej społeczności.
          </p>
        </div>

        <div className="mt-12 grid gap-6 sm:grid-cols-3">
          {LINKS.map((link, i) => (
            <motion.a
              key={link.title}
              href={link.href}
              target="_blank"
              rel="noopener noreferrer"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-60px" }}
              transition={{
                duration: 0.4,
                delay: i * 0.1,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="group flex flex-col items-center rounded-2xl border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] p-6 text-center transition-colors hover:border-accent/30"
            >
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-accent-subtle transition-colors group-hover:bg-accent/20">
                <link.icon className="h-6 w-6 text-accent" />
              </div>
              <h3 className="mt-4 text-base font-semibold">{link.title}</h3>
              <p className="mt-2 text-sm text-[var(--color-fg-muted)]">
                {link.description}
              </p>
              <span className="mt-4 text-sm font-medium text-accent">
                {link.label} →
              </span>
            </motion.a>
          ))}
        </div>
      </div>
    </section>
  );
}
