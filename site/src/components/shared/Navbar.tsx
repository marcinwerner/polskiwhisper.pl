"use client";

import { useState, useEffect } from "react";
import { Menu, X, Download } from "lucide-react";
import { cn } from "@/lib/cn";
import { ThemeToggle } from "./ThemeToggle";

const NAV_LINKS = [
  { label: "Jak to działa", href: "#how-it-works" },
  { label: "Dla kogo", href: "#use-cases" },
  { label: "Demo", href: "#demo" },
  { label: "FAQ", href: "#faq" },
  { label: "Roadmapa", href: "#roadmap" },
] as const;

export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    function onScroll() {
      setScrolled(window.scrollY > 20);
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    if (mobileOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [mobileOpen]);

  function handleNavClick(e: React.MouseEvent<HTMLAnchorElement>, href: string) {
    if (!href.startsWith("#")) return;
    const id = href.slice(1);
    const target = document.getElementById(id);
    if (!target) return;
    e.preventDefault();
    const offset = 80;
    const top = target.getBoundingClientRect().top + window.scrollY - offset;
    window.scrollTo({ top, behavior: "smooth" });
    history.pushState(null, "", href);
    setMobileOpen(false);
  }

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 transition-all duration-300",
        scrolled
          ? "border-b border-[var(--color-border-subtle)] bg-[var(--color-bg)]/80 backdrop-blur-xl"
          : "bg-transparent"
      )}
    >
      <nav className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Logo */}
        <a
          href="#"
          className="flex items-center gap-2 text-lg font-bold transition-opacity hover:opacity-80"
          onClick={(e) => {
            e.preventDefault();
            window.scrollTo({ top: 0, behavior: "smooth" });
          }}
        >
          <span className="text-accent">Polski</span>Whisper
        </a>

        {/* Desktop links */}
        <ul className="hidden items-center gap-1 md:flex">
          {NAV_LINKS.map((link) => (
            <li key={link.href}>
              <a
                href={link.href}
                onClick={(e) => handleNavClick(e, link.href)}
                className="rounded-lg px-3 py-2 text-sm font-medium text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)] hover:bg-[var(--color-bg-elevated)]"
              >
                {link.label}
              </a>
            </li>
          ))}
        </ul>

        {/* Desktop right side */}
        <div className="hidden items-center gap-3 md:flex">
          <ThemeToggle />
          <a
            href="#download"
            onClick={(e) => handleNavClick(e, "#download")}
            className="inline-flex h-9 items-center gap-2 rounded-lg bg-accent px-4 text-sm font-semibold text-[var(--color-accent-fg)] transition-all hover:bg-accent-hover active:scale-[0.97]"
          >
            <Download className="h-4 w-4" />
            Pobierz
          </a>
        </div>

        {/* Mobile right side */}
        <div className="flex items-center gap-2 md:hidden">
          <ThemeToggle />
          <button
            onClick={() => setMobileOpen(!mobileOpen)}
            className="flex h-9 w-9 items-center justify-center rounded-lg border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)]"
            aria-label={mobileOpen ? "Zamknij menu" : "Otwórz menu"}
            aria-expanded={mobileOpen}
          >
            {mobileOpen ? (
              <X className="h-4 w-4" />
            ) : (
              <Menu className="h-4 w-4" />
            )}
          </button>
        </div>
      </nav>

      {/* Mobile menu */}
      <div
        className={cn(
          "md:hidden overflow-hidden transition-all duration-300 border-b border-[var(--color-border-subtle)] bg-[var(--color-bg)]/95 backdrop-blur-xl",
          mobileOpen ? "max-h-[400px] opacity-100" : "max-h-0 opacity-0 border-b-0"
        )}
      >
        <ul className="space-y-1 px-4 pb-4 pt-2">
          {NAV_LINKS.map((link) => (
            <li key={link.href}>
              <a
                href={link.href}
                onClick={(e) => handleNavClick(e, link.href)}
                className="block rounded-lg px-3 py-2.5 text-sm font-medium text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)] hover:bg-[var(--color-bg-elevated)]"
              >
                {link.label}
              </a>
            </li>
          ))}
          <li className="pt-2">
            <a
              href="#download"
              onClick={(e) => handleNavClick(e, "#download")}
              className="flex h-11 items-center justify-center gap-2 rounded-lg bg-accent text-sm font-semibold text-[var(--color-accent-fg)] transition-all hover:bg-accent-hover"
            >
              <Download className="h-4 w-4" />
              Pobierz
            </a>
          </li>
        </ul>
      </div>
    </header>
  );
}
