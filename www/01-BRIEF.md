# 01 - BRIEF: Landing page polskiwhisper.pl

**Wersja**: 1.0 (2026-05-09)
**Cel**: zbudować "wymaksowaną" stronę dla darmowej, otwartoźródłowej aplikacji PolskiWhisper

---

## Kontekst projektu

PolskiWhisper to darmowa, otwartoźródłowa aplikacja do dyktowania głosowego po polsku, działająca offline po pobraniu modelu Whisper.

- **Repo apki**: https://github.com/marcinwerner/polskiwhisper.pl
- **macOS**: v0.1.5+ stabilna, .dmg do pobrania z GitHub Releases
- **Windows**: v0.1.0-preview pre-release, .zip 113 MB do pobrania (placeholder UI, pełne dyktowanie w v0.2.0)
- **Filozofia**: "stabilny hobby project, nie premium polished" - bez telemetrii, bez phone-home, MIT, audytowalność kodu publicznego
- **Stack apki**: WhisperKit (macOS) / Whisper.net (Windows), Apple Silicon ANE / DirectML GPU
- **Funkcje**: hotkey toggle/hold, Esc cancel, auto-spacing po `.!?`, hallucination filter, find&replace słownik, 9 dźwięków, floating waveform window

Pełną listę funkcji i historię releaseów znajdziesz w `02-CONTENT.md`.

## Cel landingu

Strona ma sprzedać **dwie rzeczy** w 5 sekundach od scrolla:

- **a)** **Po co**: "piszesz 3x szybciej, mówiąc po polsku, w dowolnej aplikacji"
- **b)** **Komu**: "darmowe, offline, kod publiczny, zero telemetrii"

### Target user

- Polski programista używający Cursor / VSCode (komentarze, prompty do AI, code review)
- Pisarz / dziennikarz / copywriter (artykuły, maile, notatki)
- Researcher / student (notatki z wykładów, źródeł, tłumaczenie myśli na tekst)
- Każdy kto pisze >2h dziennie i chciałby pisać szybciej

### Cel emocjonalny

Po wejściu na stronę użytkownik czuje: "ok, to jest poważne narzędzie, działa po polsku, jest darmowe, nie szpieguje mnie - pobieram TERAZ".

Strona NIE jest enterprise SaaS - to hobby project z passion. Tone: "spokojny ekspert który dzieli się czymś dobrym", nie "agresywny marketingowiec".

## Tech stack (wymaksowany Vercel)

### Framework

- **Next.js 15** + App Router + Turbopack
- **React 19** (Server Components, Actions, useOptimistic)
- **TypeScript 5.5+** strict (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`)
- **Tailwind CSS v4** (CSS-first config, oklch palette, native `@layer`)

### Vercel features - WSZYSTKO co ma sens

- **Partial Prerendering (PPR)** - statyczna powłoka + dynamic islands dla GitHub stats
- **Edge Runtime** dla API routes (geo-aware messaging tam gdzie sensowne)
- **`@vercel/og`** - dynamiczne OG images per release version (Hero "Pobierz v0.1.5 dla macOS" zmienia się automatycznie)
- **Vercel Image Optimization** (AVIF + WebP, lazy + blurhash placeholders)
- **Vercel Font Optimization** (next/font, self-host Google Fonts)
- **Vercel Analytics** + **Speed Insights** (RUM, Core Web Vitals, privacy-first)
- **Vercel KV (Redis)** - cache GitHub stars / downloads counters z 5 min TTL
- **Vercel Cron** - daily refresh GitHub release stats (download count, latest version, asset URLs)
- **Vercel AI SDK** - jeśli zdecydujesz się na server-side fallback dla demo Whisper
- **Speculation Rules API** - prefetch download links na hover (instant download)
- **Skew protection** włączone
- **Preview Deployments** + comments dla każdego PR
- **Sitemap + robots.txt** auto via `app/sitemap.ts` i `app/robots.ts`

### Animacje (kombo, nie monoteizm jednej biblioteki)

Wybierz narzędzie do zadania, nie odwrotnie:

- **Framer Motion / Motion** (successor) - layout animations, page transitions, scroll-linked variants
- **GSAP + ScrollTrigger** - skomplikowane scroll-driven sequences (timeline-style w "How it works")
- **Lottie** - mikro-animacje (icons, success states, complete checkmarks)
- **Three.js / React Three Fiber** - 3D mockup laptopa z apką (lazy loaded, only desktop, fallback do statycznego image)
- **Native CSS scroll-driven animations** (`animation-timeline: scroll()`) - tam gdzie wystarczą JavaScript-free

### Najnowsze APIs - use them, with progressive enhancement

- **View Transitions API** (same-document + cross-document gdy stable)
- **Scroll-driven animations** (CSS native + JS fallback)
- **`@scope` CSS** dla izolacji stylów sekcji
- **`:has()` selector** dla parent-aware styling
- **Container queries** `@container`
- **Anchor positioning** (gdzie wspierane, fallback do absolute)
- **Popover API native** (zamiast Radix Dropdown gdzie sensowne)
- **`text-wrap: balance`** dla nagłówków (auto-balance lines)
- **`@starting-style`** dla entry animations bez JS
- **`color-mix()` + oklch palette** (modern color mixing)
- **View Transitions Names** dla shared element transitions między stronami
- **`prefers-reduced-motion` ZAWSZE** respektowane

### Stretch goal: WebGPU Whisper demo

**Pomysł**: user może w przeglądarce nagrać 10 sek mikrofonem i zobaczyć transkrypcję bez instalacji apki.

- **Transformers.js** + **Whisper Tiny ONNX** (~75 MB) → in-browser transcription
- Model **lazy-loaded on click** (nie blokuje LCP, nie zwiększa initial bundle)
- **Service Worker cache** dla powtórnych wizyt (75 MB raz)
- Komunikat: "to demo używa modelu Tiny dla szybkości; aplikacja używa większego modelu z dokładnością ~95%"
- **Progressive enhancement**: jeśli nie ma WebGPU (Safari < 18, mobile, starsze Chrome), fallback na pre-recorded loop video

**Argument marketingowy**: "to ten sam Whisper który masz w aplikacji, działa offline w Twojej przeglądarce". Wzmacnia privacy positioning.

**Decyzja czy implementować**: pytanie do Marcina (sekcja "Pytania do uściślenia"). Jeśli za duży scope - zostań przy pre-recorded loop video.

## Sekcje strony

### 1. Hero

- **Nagłówek 2-4 słowa, ogromny**: "Mówisz. Piszesz." (lub "Pisz głosem. Po polsku.")
- **Sub-nagłówek 1 zdanie**: "Darmowa aplikacja do dyktowania w macOS i Windows. Działa offline. Twoje audio nigdy nie opuszcza komputera."
- **Live demo placeholder** z animowanymi waveformami + tekstem typewriter-stylem ("Po prostu mów po polsku, a tekst pojawi się tam gdzie kursor.")
- **Dwa CTA**: **Pobierz dla macOS** | **Pobierz dla Windows (preview)**
- **Mała dolna linia**: "✓ MIT  ✓ Open source  ✓ Zero telemetrii"
- **GitHub stars badge** (live, z Vercel KV cache)

### 2. "Przekonaj się sam" (interaktywne demo - WebGPU)

**Conditional - tylko jeśli Marcin zdecyduje "tak" w pytaniach uściślających**.

- Bunkry guard: "wymaga WebGPU + ~75 MB do pobrania (jednorazowo)"
- Przycisk "Mów teraz" → autoryzacja mic → 10 sek nagrania → transkrypcja inline
- Caveat copy: "to demo używa modelu Tiny dla szybkości; aplikacja używa większego modelu z dokładnością ~95%"
- Fallback: 30 sek pre-recorded loop video z prawdziwego użycia apki

### 3. "Ile czasu zaoszczędzisz" (productivity calculator)

- **Slider input**: "Ile minut dziennie piszesz na klawiaturze?" (15 - 480 min, default 90)
- **Animowane wyliczenie real-time** (na każdą zmianę slidera):
  - Średnia prędkość pisania: 40 słów/min
  - Średnia prędkość mówienia: 130 słów/min
  - "Z PolskiWhisper zyskujesz **N godzin tygodniowo / M dni rocznie**"
- **Ikonka kalendarza** z animowanym wypełnianiem dni rocznie (52 tygodnie × 7 dni = 364 kafelki)
- **Color gradient** od zimnego (mało godzin) do ciepłego (dużo)
- **CTA**: "Pobierz teraz, oszczędzaj jutro"

### 4. "Jak to działa" (3 kroki)

- **Krok 1**: Pobierz aplikację (mac/win)
- **Krok 2**: Pobierz model Whisper (1×, ~1.5 GB) - "po tym pełny offline"
- **Krok 3**: Wciśnij hotkey i mów

Każdy krok = animacja (Lottie / Framer Motion sequence). ScrollTrigger sekwencyjne odsłanianie z pin-pinned section.

### 5. "Use cases" (carousel z animacjami)

Każdy use case = animowane mockup pokazujące przed/po:

- **Programista**: dyktuje komentarz w Cursor / pisze prompt do Claude Code
- **Pisarz**: tworzy szkic artykułu / odpowiedź na maila
- **Researcher**: notatki z PDF-a / cytowanie źródła
- **Każdy**: szybka odpowiedź w Slacku / Discordzie

**Auto-rotating** co 5 sek + **manual navigation** (arrows + dots). Smooth crossfade.

### 6. "Privacy first" (wyróżnik)

Trzy punkty z ikonami:

- **Offline po setupie** - audio nigdy nie opuszcza komputera
- **Zero telemetrii** - kod sprawdzalny w GitHub, audyty welcome
- **Open source MIT** - możesz forknąć, modyfikować, użyć komercyjnie

Kontekst: na tle wycieków danych z chmurowych narzędzi, lokalność = killer feature.

### 7. Download (sticky / prominent)

- **Tab macOS / Windows** (default macOS, bo bardziej dojrzała wersja)
- **macOS**: bezpośredni link do .dmg z najnowszego release + verify SHA256
- **Windows**: bezpośredni link do .zip (113 MB) + UWAGA pre-release v0.1.0-preview (placeholder UI)
- **Wymagania systemowe** inline (macOS 14+ Apple Silicon / Windows 10 1809+)
- **Quick start**: "co po pobraniu" (3 punkty)

### 8. Roadmap (timeline)

Poziomy timeline z statusami:

- v0.1.5 macOS ✅ (stable)
- v0.1.0-preview Windows ✅ (placeholder UI)
- v0.2.0 Windows 🔜 (full UI, dyktowanie)
- v1.0.0 🎯 (parity, target Q3 2026)

### 9. FAQ (accordion)

Most-asked (pełna treść w 02-CONTENT.md):

- "Czy to naprawdę darmowe?"
- "Co z prywatnością?"
- "Jak dokładne są transkrypcje?"
- "Jakie języki?"
- "GPU jest wymagane?"
- "Mogę używać w pracy / komercyjnie?"
- "Dlaczego nie ma w App Store / Microsoft Store?"
- "Co jeśli znajdę bug?"

### 10. Community / contribution

- "Otwarty kod, otwarte issues" - link do GitHub Issues
- "Znalazłeś bug?" - link do bug report template
- "Chcesz pomóc?" - link do CONTRIBUTING.md
- Discord / Slack? (do decyzji - zostaw placeholder, na start tylko GitHub Issues)

### 11. Footer

- Logo + tagline ("Pisz głosem. Po polsku. Za darmo.")
- Kolumny: Produkt / Społeczność / Prawne / Kontakt
- Linki: GitHub / Email / RSS releases
- "© 2026 Marcin Werner. MIT license."
- Subtelny easter egg "made with PolskiWhisper" (jeśli copy pisany dyktowaniem)

## Animacje (per sekcja, konkretnie)

### Hero
- Waveform na tle (canvas / SVG, perlin noise pseudo-real, 60 fps na dobrym GPU, fallback static SVG)
- Typewriter effect z cycle: 4 zdania ("Pisz dwa razy szybciej.", "Po polsku.", "Bez chmury.", "Za darmo.")
- Pulsujący glow wokół CTA "Pobierz" (subtle, max 0.3s loop, pause na hover)
- Particles albo subtle gradient mesh w tle (CSS `color-mix` + animation)

### Productivity calculator
- Slider z haptic-like feedback (scale on grab, drop shadow grow)
- Liczby liczone animowanym counter (CountUp.js / Framer Motion `<motion.span>`)
- Kalendarz roczny (52 tyg × 7 dni) wypełniający się "kafelkami" reprezentującymi zaoszczędzone godziny
- Color gradient od zimnego (mało godzin) do ciepłego (dużo)

### How it works (3 kroki)
- Scroll-triggered timeline (GSAP ScrollTrigger pin)
- Każdy krok pojawia się gdy w viewport, sekwencyjnie
- Mockup okna apki z animowanym onboardingiem (Lottie - małe SVG animacje)

### Use cases carousel
- Auto-rotating co 5 sek + manual navigation
- Każdy use case = video loop (small, lossless WebM, lazy)
- Smooth crossfade między use casami

### Privacy first
- Trzy ikony pulsujące alternate (jedna na raz, 3 sek interval)
- Na hover: rotate 360° + scale up (CSS transform)

### Roadmap timeline
- Scroll-linked progress bar wypełnia się w miarę scrolla
- Każdy milestone "wyskakuje" z animacją scale + opacity
- Aktualny milestone (`v0.1.0-preview`) ma pulsing dot

### Reduced motion
- WSZYSTKIE animacje w `@media (prefers-reduced-motion: reduce)` redukują się do statycznych stanów
- Decorative animations skip
- Critical animations (focus indicators, loading states) zostają

## Performance budgets

### Lighthouse target (desktop + mobile)

- **Performance**: 95+
- **Accessibility**: 95+
- **Best Practices**: 100
- **SEO**: 100

### Core Web Vitals

- **LCP** < 1.5s
- **INP** < 200ms
- **CLS** < 0.05

### Bundle size

- **Initial JS**: < 100 kB (gzipped)
- **Initial CSS**: < 30 kB
- **Whisper Tiny model**: lazy on demand (NIE w initial)

### Critical resources

- Hero text: instant (HTML)
- Hero waveform: progressive enhancement (canvas po `requestIdleCallback`)
- Below-fold assets: lazy + intersection observer

## SEO + dostępność

### SEO

- Meta tags (title, description, OG, Twitter Card)
- JSON-LD `SoftwareApplication` + `Organization` + `BreadcrumbList`
- Dynamiczne OG image dla landing + każdej wersji release
- Sitemap + robots.txt (auto via `app/sitemap.ts`, `app/robots.ts`)
- Hreflang gdy dodasz EN
- Canonical URLs
- Open Graph dla każdej sekcji (deep links anchor)

### A11y

- WCAG 2.2 **AA minimum**, AAA dla key text
- Keyboard navigation (focus indicators visible)
- Screen reader testing (VoiceOver + NVDA)
- ARIA labels dla wszystkich interaktywnych
- Skip-to-content link
- Color contrast: **7:1 dla body text**, 4.5:1 dla large text
- Form labels associated
- Video: captions, transcripts dla wszystkich
- `prefers-reduced-motion` respect (cała strona użyteczna z reduce)
- `prefers-color-scheme` respect (light + dark obie pełne, nie tylko inverted)
- Focus management dla SPA navigation

## Konwencje kodu

### Struktura

```
app/
  (marketing)/
    page.tsx              # Home
    privacy/page.tsx
    download/page.tsx
  api/
    og/route.tsx          # Dynamic OG
    github-stats/route.ts # KV-cached
    transcribe/route.ts   # (jeśli server-side fallback)
components/
  hero/
  demo/
  calculator/
  how-it-works/
  use-cases/
  privacy/
  download/
  roadmap/
  faq/
  footer/
  shared/
lib/
  github.ts               # Octokit + KV cache
  analytics.ts            # Event helpers
  motion.ts               # Framer Motion variants
  whisper-client.ts       # transformers.js wrapper
public/
  videos/
  fonts/
content/
  faq.ts
  use-cases.ts
  roadmap.ts
```

### Kod

- **TypeScript strict** + `noUncheckedIndexedAccess` + `exactOptionalPropertyTypes`
- **ESLint + Prettier** (Next.js config + custom rules)
- **Tailwind config**: oklch palette, custom motion variables, dark mode `class` strategy
- **Komponenty**: small, single-purpose, prop-drilled (NIE Context dla wszystkiego)
- **Server Components first**, Client Components tylko gdzie potrzeba interaktywności
- **Co-location**: tests obok komponentu (`Component.test.tsx`)

### Testy

- **Vitest + Testing Library** dla unit
- **Playwright** dla E2E (smoke testy przepływów: hero → CTA → download URL)
- **Lighthouse CI** w GitHub Actions
- **Visual regression**: Percy / Chromatic (opcjonalne)

### CI/CD

- **GitHub Actions**: lint + type-check + tests + Lighthouse
- **Vercel deploy** on push (auto preview, prod on main)
- **Branch protection**: requires CI green
- **Conventional Commits**

## Tonalność copy

Pełne wytyczne: `03-BRAND.md`. TLDR:

- **Polski język** ZAWSZE z diakrytycznymi (ą, ę, ś, ć, ź, ż, ó, ł, ń)
- **"-"** zamiast **"—"** (krótka pauza)
- **Przyjazny, NIE alarmistyczny** ton
- **"Co user zyskuje"** framing, NIE "co my zrobiliśmy"
- **Bez technicznego żargonu** w main copy (techniczne info ukryte w "Dla developerów" FAQ)
- **Krótkie zdania**, pojedyncze idee per zdanie
- **Active voice**
- **"Ty" forma** (nie "Państwo", nie 3 os.)

## Vercel deployment

Pełne wytyczne: `04-DEPLOYMENT.md`. TLDR:

- **Repo**: `polskiwhisper-landing` (osobne od głównego apka repo)
- **Domeny**: `polskiwhisper.pl` (apex) + `www.polskiwhisper.pl` (redirect to apex)
- **DNS**: Cloudflare (Marcin używa CF) lub Vercel native
- **SSL**: auto Vercel
- **Env vars**: `GITHUB_TOKEN`, `KV_REST_API_URL`, `KV_REST_API_TOKEN`, `NEXT_PUBLIC_VERCEL_ANALYTICS_ID`

## Deliverables

Sesja ma wyprodukować:

- **a)** Działające repo `polskiwhisper-landing` z całą stroną
- **b)** Deployed preview na Vercel (URL w summary)
- **c)** README.md z instrukcją lokalnego uruchomienia + setup env vars + deploy
- **d)** CONTRIBUTING.md (krótki, dla open-source kontrybucji)
- **e)** Screenshoty desktop/mobile wszystkich sekcji w `/docs/screenshots/`
- **f)** Lighthouse CI report dołączony do README z scores 95+
- **g)** Lista technicznych decyzji w `docs/DECISIONS.md` (mini ADR-y)

## Quality bar - kiedy strona jest "wymaksowana"

- ✅ **Lighthouse 95+** wszystkie 4 metryki, na desktop i mobile
- ✅ **Core Web Vitals** wszystkie zielone (LCP <1.5s, INP <200ms, CLS <0.05)
- ✅ **Bundle <100 kB** initial JS
- ✅ **A11y**: keyboard-only navigation działa od początku do końca strony
- ✅ **WebGPU demo** działa w Chrome 121+ z fallback dla Safari (jeśli zaimplementowane)
- ✅ **Mobile-first**: każda animacja przetestowana na iPhone 12 / Android mid-range
- ✅ **Reduced motion**: cała strona użyteczna z `prefers-reduced-motion: reduce`
- ✅ **Dark mode** + light mode obie pełne (nie tylko inverted colors)
- ✅ **Print stylesheet** podstawowy (dla osób które chcą wydrukować)
- ✅ **Real device testing**: macOS Safari, iOS Safari, Windows Chrome, Android Chrome - wszędzie OK
- ✅ **Lokalność**: GDPR-compliant, brak third-party cookies bez consent
- ✅ **Open Graph**: każdy share na Twitter/LinkedIn/Discord pokazuje hero image z tekstem

Jeśli masz wątpliwość czy "wystarczająco wymaksowane" - dorzuć następną warstwę polish (mikro-animacja, easter egg, nieoczywiste detail UX).

## Pre-launch checklist

- [ ] DNS propagated, SSL valid
- [ ] Sitemap + robots indexable
- [ ] OG image renders correctly w Twitter Validator + Facebook Debugger
- [ ] Analytics fires events poprawnie
- [ ] CTA "Pobierz" linkuje do najnowszego release (auto via GitHub API)
- [ ] FAQ pokrywa top 10 pytań z GitHub Issues
- [ ] Privacy policy linkowana w footerze
- [ ] Newsletter signup (jeśli planowany) - lub explicite "nie zbieramy emaili"
- [ ] 404 + 500 pages mają personality
- [ ] Loading states wszędzie gdzie async (skeleton lub spinner)
- [ ] Error boundaries z friendly fallback

## Pytania do uściślenia (zadaj Marcinowi przed startem)

Zacznij sesję od zadania tych 6 pytań i CZEKAJ na odpowiedzi PRZED kodowaniem:

- **a)** **Branding**: czy jest gdzieś logo / mark dla PolskiWhisper, czy generujemy podstawowe (typograficzne)?
- **b)** **Kolor accent**: ciepły (orange/coral) jak Claude brand, polski czerwony, czy neutral monochrome?
- **c)** **i18n**: PL only na start, czy od razu PL + EN?
- **d)** **WebGPU demo**: czy chcesz interaktywne (opóźnia LCP, zwiększa złożoność, ~75 MB) czy pre-recorded loop video (szybsze, prostsze)?
- **e)** **Newsletter / waitlist**: tak / nie?
- **f)** **Affiliate w stopce**: "Made by Marcin Werner" + link do strony Marcina, czy bez personal branding?

## Co działa "out of the box" w tym briefie

Ten brief oczekuje, że agent w nowej sesji:

- Stworzy świeże repo (lub poprosi user o utworzenie)
- Zainstaluje Next.js 15 + całą resztę
- Zbuduje stronę sekcja po sekcji, commitując często
- Zdeploy na Vercel (jeśli ma access) lub poprosi user o connect
- Napisze testy + Lighthouse CI
- Wypełni FAQ i copy z konkretami z głównego repo (przeczyta `02-CONTENT.md`)
- Zwróci na końcu: link do prod, link do repo, screenshoty, summary techniczny

**Action item dla agenta**: dostarczasz brief jak komuś kto pierwszy raz słyszy o projekcie - zacznij od pytania 6 rzeczy z sekcji "Pytania do uściślenia", czekaj na odpowiedzi, potem koduj.

Powodzenia. To ma być najlepsza polska app landing 2026 roku.
