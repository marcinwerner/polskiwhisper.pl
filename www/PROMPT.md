# Prompt do nowej sesji Claude Code Desktop

**Marcin pracuje wyłącznie w Claude Code Desktop.** Workflow uruchomienia nowej sesji:

- **a)** W Claude Code Desktop otwórz **nowe okno / nowy projekt** z working directory ustawionym na **`~/Documents/GitHub/polskiwhisper.pl/`** (folder repo apki, NIE pusty folder dla strony)
- **b)** Wklej poniższy prompt jako pierwszą wiadomość w nowej sesji
- **c)** Agent czyta brief z `www/`, ma pełny dostęp do kodu macOS / Windows / dokumentacji repo, zadaje pytania (w tym 7. pytanie: gdzie ma trafić kod strony - mono-repo czy osobne repo), czeka na odpowiedzi, koduje

---

```
Twoje zadanie: zbudować landing page polskiwhisper.pl - "wymaksowaną" stronę dla darmowej, otwartoźródłowej aplikacji do dyktowania głosowego po polsku.

KONTEKST - working directory

Pracujesz w folderze /Users/Marcin/Documents/GitHub/polskiwhisper.pl/ - to jest repozytorium aplikacji PolskiWhisper. Masz pełny dostęp do:
- Kodu macOS (PolskiWhisper/, Swift)
- Kodu Windows (windows/, C# WinUI 3)
- Dokumentacji (README, CHANGELOG, docs/)
- Briefu landing page (www/)
- Wszystkich pozostałych plików repo

Brief mówi o "osobnym repo polskiwhisper-landing" - to było pierwotne założenie. JEDNO Z PYTAŃ DO MARCINA to gdzie ma trafić kod strony (osobne repo vs ten sam repo). NIE zakładaj rozwiązania - zapytaj.

KROK 1 - Przeczytaj brief

Brief znajduje się w katalogu www/ tego repozytorium. Przeczytaj WSZYSTKIE pliki w tej kolejności:

1. www/README.md (intro do briefu)
2. www/01-BRIEF.md (główny brief - najważniejszy)
3. www/02-CONTENT.md (źródła treści, FAQ, fakty o apce)
4. www/03-BRAND.md (wytyczne wizualne, copywriting)
5. www/04-DEPLOYMENT.md (Vercel + DNS + monitoring)

KROK 2 - Przeczytaj materiały źródłowe z repo apki

Pliki w bieżącym repo (lista w 02-CONTENT.md):
- README.md (root) - macOS user-facing
- windows/README.md - Windows user-facing
- CHANGELOG.md (root) - historia macOS
- windows/CHANGELOG.md - historia Windows
- SECURITY.md, CONTRIBUTING.md, ACKNOWLEDGEMENTS.md, LICENSE
- (opcjonalnie) windows/docs/ARCHITECTURE.md, windows/docs/PRIVACY.md

Pomiń: PolskiWhisper/* (Swift code), windows/src/* (C# code), .internal/* (gitignored), .git/*

KROK 3 - Zadaj 7 pytań uściślających

W pliku www/01-BRIEF.md na końcu jest sekcja "Pytania do uściślenia" z 6 pytaniami (a-f). Dodatkowo zadaj 7. pytanie:

g) Lokalizacja kodu strony: mono-repo (kod w www/site/ tego repo, deploy z subdir Vercel) czy multi-repo (osobny repo polskiwhisper-landing)? 
   - mono-repo: prościej, jeden git, ale mieszanie kontekstu macOS/Windows/web
   - multi-repo: czystszy podział odpowiedzialności, ale dwa miejsca do utrzymania

Zadaj wszystkie 7 pytań w pierwszej wiadomości i CZEKAJ NA ODPOWIEDZI.

KROK 4 - Po akceptacji odpowiedzi - zacznij implementację

Stack: Next.js 15 + Vercel + TypeScript strict + Tailwind v4 + Framer Motion + GSAP. Lokalizacja kodu zależy od odpowiedzi na pytanie 7.

KROK 5 - Quality bar

Cel: Lighthouse 95+ wszystkie 4 metryki, Core Web Vitals zielone, A11y WCAG AA min, mobile-first, prefers-reduced-motion respect, dark + light mode pełne.

KROK 6 - Commits

Commituj często. Pierwsza wersja: scaffold + hero + footer + Vercel preview deploy. Następne iteracje per sekcja.

WAŻNE konwencje (preferencje Marcina):
- Marcin pracuje WYŁĄCZNIE w Claude Code Desktop - NIE pisz "otwórz terminal i wpisz claude". Komendy bash uruchamiasz Ty (przez tool Bash w sesji), nie Marcin w external terminal
- Polski język w copy z polskimi znakami diakrytycznymi (ą, ę, ś, ć, ź, ż, ó, ł, ń)
- "-" (krótka pauza) zamiast "—" (em dash)
- Friendly, NIE alarmistyczny ton (per 03-BRAND.md)
- Litery a/b/c przy listach 2+ punktów
- Nie commituj sekretów (env vars przez Vercel Dashboard)
- AUDIT-PROPOSE-WAIT-EXECUTE dla destrukcyjnych zmian (DNS, account creation)
- Nazwy klucze (repo names, Vercel project, env vars) wymagają akceptacji Marcina przed utworzeniem

Powodzenia! Zaczynamy od KROK 1.
```

---

## Checklist przed wklejeniem

- **a)** Otwarte nowe okno Claude Code Desktop z working directory na **`~/Documents/GitHub/polskiwhisper.pl/`** (folder repo apki - nowa sesja ma full access do kodu macOS/Windows/dokumentacji/briefu)
- **b)** Marcin ma przygotowane odpowiedzi na 7 pytań uściślających:
  - 6 z `01-BRIEF.md` (branding, kolor, i18n, WebGPU, newsletter, personal branding)
  - 7. dodatkowe: mono-repo (kod w `www/site/`) czy multi-repo (osobny repo `polskiwhisper-landing`)?
- **c)** (Lub Marcin odpowie "decyduj sam" jeśli nie ma zdania - agent ma rekomendacje)

Po wklejeniu agent przeczyta pliki, zada 7 pytań, Marcin odpowiada, lecimy.

## Alternative: krótszy prompt jeśli chcesz "v0.1 landing w 1 dzień"

Jeśli pełen scope (z WebGPU demo, calculator productivity itp.) jest overkill na start - daj znać, dopiszę `PROMPT-MINI.md` z statycznym landingiem 3 sekcje (hero + features + download), gotowy w 1 dzień, bez bells and whistles.
