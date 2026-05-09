# Prompt do nowej sesji Claude Code Desktop

**Marcin pracuje wyłącznie w Claude Code Desktop.** Workflow uruchomienia nowej sesji:

- **a)** Utwórz folder docelowy (jeśli nie istnieje) - z bieżącej sesji Claude Code Desktop wykonaj: `mkdir -p ~/Documents/GitHub/polskiwhisper-landing` (przez tool Bash)
- **b)** W Claude Code Desktop otwórz **nowe okno / nowy projekt** i ustaw working directory na ten folder (przez UI Claude Code Desktop)
- **c)** Wklej poniższy prompt jako pierwszą wiadomość w tej nowej sesji

---

```
Twoje zadanie: zbudować landing page polskiwhisper.pl - "wymaksowaną" stronę dla darmowej, otwartoźródłowej aplikacji do dyktowania głosowego po polsku.

KROK 1 - Przeczytaj brief

Brief znajduje się w katalogu `www/` repozytorium PolskiWhisper:
- /Users/Marcin/Documents/GitHub/polskiwhisper.pl/www/

Przeczytaj WSZYSTKIE pliki w tej kolejności:
1. /Users/Marcin/Documents/GitHub/polskiwhisper.pl/www/README.md (intro)
2. /Users/Marcin/Documents/GitHub/polskiwhisper.pl/www/01-BRIEF.md (główny brief - najważniejszy)
3. /Users/Marcin/Documents/GitHub/polskiwhisper.pl/www/02-CONTENT.md (źródła treści)
4. /Users/Marcin/Documents/GitHub/polskiwhisper.pl/www/03-BRAND.md (wytyczne wizualne)
5. /Users/Marcin/Documents/GitHub/polskiwhisper.pl/www/04-DEPLOYMENT.md (Vercel + DNS)

KROK 2 - Przeczytaj materiały źródłowe z repo apki

Z pliku 02-CONTENT.md masz listę plików do przeczytania (głównie /README.md, /CHANGELOG.md, /windows/README.md, /windows/CHANGELOG.md w repo apki). Przeczytaj wszystkie - znajdziesz tam fakty, copy, feature listy.

KROK 3 - Zadaj pytania uściślające

W pliku 01-BRIEF.md na końcu jest sekcja "Pytania do uściślenia" - 6 pytań od brandingu po WebGPU. Zadaj je Marcinowi w pierwszej wiadomości i CZEKAJ NA ODPOWIEDZI.

KROK 4 - Po akceptacji odpowiedzi - zacznij implementację

Zgodnie z planem w 01-BRIEF.md. Stack: Next.js 15 + Vercel + TypeScript + Tailwind v4 + Framer Motion + GSAP. Tworzysz w bieżącym folderze (cwd nowej sesji).

KROK 5 - Quality bar

Cel: Lighthouse 95+ wszystkie 4 metryki, Core Web Vitals zielone, A11y WCAG AA min, działa offline (cache), respektuje prefers-reduced-motion, mobile-first.

KROK 6 - Commits

Commituj często. Pierwsza wersja - kompletny scaffold + hero + footer + deploy preview na Vercel. Następne iteracje per sekcja.

WAŻNE konwencje (zgodne z preferencjami Marcina):
- Marcin pracuje WYŁĄCZNIE w Claude Code Desktop - NIE pisz "otwórz terminal i wpisz claude". Komendy bash uruchamiasz Ty (przez tool Bash w sesji), nie Marcin w external terminal
- Polski język w copy z polskimi znakami diakrytycznymi (ą, ę, ś, ć, ź, ż, ó, ł, ń)
- "-" (krótka pauza) zamiast "—" (em dash)
- Friendly, NIE alarmistyczny ton (per 03-BRAND.md)
- Litery a/b/c przy listach 2+ punktów
- Nie commituj sekretów
- AUDIT-PROPOSE-WAIT-EXECUTE dla destrukcyjnych zmian (rzadko potrzebne tu)

Powodzenia! Zaczynamy od KROK 1.
```

---

## Checklist przed wklejeniem

- **a)** Folder `~/Documents/GitHub/polskiwhisper-landing/` istnieje (jeśli nie - utwórz w bieżącej sesji przez `mkdir -p`)
- **b)** Otwarte nowe okno Claude Code Desktop z working directory na ten folder
- **c)** Repo apki PolskiWhisper jest dostępne pod ścieżką `/Users/Marcin/Documents/GitHub/polskiwhisper.pl/` (tak jest aktualnie - nic nie trzeba robić)
- **d)** Marcin ma przygotowane odpowiedzi na 6 pytań uściślających z `01-BRIEF.md` (lub odpowie "decyduj sam" jeśli nie ma zdania)

Po wklejeniu agent przeczyta pliki, zada 6 pytań, Marcin odpowiada, lecimy.

## Alternative: krótszy prompt jeśli chcesz "v0.1 landing w 1 dzień"

Jeśli pełen scope (z WebGPU demo, calculator productivity itp.) jest overkill na start - daj znać, dopiszę `PROMPT-MINI.md` z statycznym landingiem 3 sekcje (hero + features + download), gotowy w 1 dzień, bez bells and whistles.
