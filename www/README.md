# www/ - Brief landing page polskiwhisper.pl

Ten katalog zawiera **kompletny brief** do zbudowania landing page dla projektu PolskiWhisper.

Strona zostanie zbudowana w **osobnym repo** (`polskiwhisper-landing`) - ten katalog to tylko źródło prawdy: brief, wytyczne, materiały content. Po zbudowaniu landing page repo apki nie zawiera kodu strony, tylko ten brief.

## Co tu jest

| Plik | Co zawiera | Dla kogo |
|------|------------|----------|
| **PROMPT.md** | Krótki prompt do wklejenia w nowej sesji Claude Code | Marcin |
| **01-BRIEF.md** | Główny brief: cel, stack, sekcje, animacje, performance, quality bar | Agent (nowa sesja) |
| **02-CONTENT.md** | Źródła treści: linki do README, CHANGELOG, FAQ, fakty o aplikacji | Agent |
| **03-BRAND.md** | Wytyczne wizualne: kolory, typografia, ton, copywriting | Agent |
| **04-DEPLOYMENT.md** | Vercel + DNS Cloudflare + env vars + monitoring | Agent / DevOps |

## Jak użyć

**Marcin (właściciel projektu)**:
1. Skopiuj treść z [PROMPT.md](PROMPT.md)
2. Wklej w nową sesję Claude Code uruchomioną w pustym folderze (np. `~/Documents/GitHub/polskiwhisper-landing/`)
3. Agent przeczyta brief i zacznie pracę zgodnie z planem

**Agent (nowa sesja Claude Code)**:
1. Przeczytaj WSZYSTKIE pliki w tym katalogu, w kolejności 01 → 04
2. Przeczytaj też pliki referowane z `02-CONTENT.md` (głównie `/README.md` repo apki)
3. Zadaj 6 pytań uściślających (lista na końcu `01-BRIEF.md`)
4. Czekaj na odpowiedzi Marcina
5. Dopiero po odpowiedziach zacznij implementację

## Status

**Wersja briefu**: v1.0 (2026-05-09)
**Brief utworzony przez**: Claude (Sonnet 4.5) w sesji repo apki
**Przewidywany czas pierwszej wersji landing**: 2-3 dni pracy agenta z review Marcina

## Filozofia briefu

Strona ma być **wymaksowana** - najlepsza polska app landing page roku. Nie minimalistyczna, nie "wystarczy że działa". Pełne wykorzystanie Vercela, najnowszych CSS/JS APIs, odważne animacje (z respektem dla `prefers-reduced-motion`).

Jednocześnie: privacy-first, dostępna (WCAG AA min), szybka (Lighthouse 95+), mobile-first.

Cel emocjonalny: po wejściu na stronę użytkownik czuje "ok, to jest poważne narzędzie, działa po polsku, jest darmowe, nie szpieguje mnie - pobieram TERAZ".

## Pytania / zmiany w briefie

Edycje briefu = osobny commit, opisane w changelog poniżej.

### Changelog briefu

- **2026-05-09**: v1.0 - pierwsza wersja, gotowa do uruchomienia agenta
