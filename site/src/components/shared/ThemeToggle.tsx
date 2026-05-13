"use client";

import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";

export function ThemeToggle() {
  // Default light - dark tylko gdy user wcześniej kliknął księżyc (localStorage 'dark').
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    setIsDark(!document.documentElement.classList.contains("light"));
  }, []);

  function toggle() {
    const next = !isDark;
    setIsDark(next);
    document.documentElement.classList.toggle("light", !next);
    localStorage.setItem("theme", next ? "dark" : "light");
  }

  return (
    <button
      onClick={toggle}
      className="flex h-9 w-9 items-center justify-center rounded-lg border border-[var(--color-border-subtle)] bg-[var(--color-bg-elevated)] text-[var(--color-fg-muted)] transition-colors hover:text-[var(--color-fg)] hover:border-[var(--color-border)]"
      aria-label={isDark ? "Włącz jasny motyw" : "Włącz ciemny motyw"}
    >
      {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
    </button>
  );
}
