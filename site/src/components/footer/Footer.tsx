import { Mail, Rss } from "lucide-react";

function GithubIcon({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
  );
}

const LINKS = {
  produkt: [
    { label: "Pobierz", href: "#download" },
    { label: "Jak to działa", href: "#how-it-works" },
    { label: "FAQ", href: "#faq" },
    { label: "Roadmapa", href: "#roadmap" },
  ],
  spolecznosc: [
    {
      label: "GitHub",
      href: "https://github.com/marcinwerner/polskiwhisper.pl",
      external: true,
    },
    {
      label: "Issues",
      href: "https://github.com/marcinwerner/polskiwhisper.pl/issues",
      external: true,
    },
    {
      label: "Dyskusje",
      href: "https://github.com/marcinwerner/polskiwhisper.pl/discussions",
      external: true,
    },
    {
      label: "Współpraca",
      href: "https://github.com/marcinwerner/polskiwhisper.pl/blob/main/CONTRIBUTING.md",
      external: true,
    },
  ],
  prawne: [
    { label: "Prywatność", href: "/privacy" },
    {
      label: "Licencja MIT",
      href: "https://github.com/marcinwerner/polskiwhisper.pl/blob/main/LICENSE",
      external: true,
    },
    {
      label: "Bezpieczeństwo",
      href: "https://github.com/marcinwerner/polskiwhisper.pl/security/advisories/new",
      external: true,
    },
  ],
} as const;

export function Footer() {
  return (
    <footer className="border-t border-[var(--color-border-subtle)] bg-[var(--color-bg-subtle)]">
      <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {/* Brand */}
          <div>
            <p className="text-lg font-bold">PolskiWhisper</p>
            <p className="mt-2 text-sm text-[var(--color-fg-muted)]">
              Pisz głosem. Po polsku. Za darmo.
            </p>
            <div className="mt-4 flex gap-3">
              <a
                href="https://github.com/marcinwerner/polskiwhisper.pl"
                target="_blank"
                rel="noopener noreferrer"
                className="text-[var(--color-fg-subtle)] transition-colors hover:text-[var(--color-fg)]"
                aria-label="GitHub"
              >
                <GithubIcon className="h-5 w-5" />
              </a>
              <a
                href="mailto:kontakt@marcinwerner.com"
                className="text-[var(--color-fg-subtle)] transition-colors hover:text-[var(--color-fg)]"
                aria-label="Email"
              >
                <Mail className="h-5 w-5" />
              </a>
              <a
                href="https://github.com/marcinwerner/polskiwhisper.pl/releases.atom"
                target="_blank"
                rel="noopener noreferrer"
                className="text-[var(--color-fg-subtle)] transition-colors hover:text-[var(--color-fg)]"
                aria-label="RSS releases"
              >
                <Rss className="h-5 w-5" />
              </a>
            </div>
          </div>

          {/* Produkt */}
          <div>
            <h3 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-fg-subtle)]">
              Produkt
            </h3>
            <ul className="mt-3 space-y-2">
              {LINKS.produkt.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    className="text-sm text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)]"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Społeczność */}
          <div>
            <h3 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-fg-subtle)]">
              Społeczność
            </h3>
            <ul className="mt-3 space-y-2">
              {LINKS.spolecznosc.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    {...(link.external
                      ? { target: "_blank", rel: "noopener noreferrer" }
                      : {})}
                    className="text-sm text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)]"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Prawne */}
          <div>
            <h3 className="text-sm font-semibold uppercase tracking-wider text-[var(--color-fg-subtle)]">
              Prawne
            </h3>
            <ul className="mt-3 space-y-2">
              {LINKS.prawne.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    {...("external" in link
                      ? { target: "_blank", rel: "noopener noreferrer" }
                      : {})}
                    className="text-sm text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)]"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="mt-10 border-t border-[var(--color-border-subtle)] pt-6 text-center text-sm text-[var(--color-fg-subtle)]">
          <p>© 2026 Marcin Werner. MIT license.</p>
        </div>
      </div>
    </footer>
  );
}
