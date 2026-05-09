# 03 - BRAND: Wytyczne wizualne i tonalność

**Cel**: spójna identyfikacja wizualna i tonalna landing page polskiwhisper.pl.

---

## Brand essence

**Po co istniejemy**: żeby Polacy mogli pisać głosem - szybciej, prywatniej, za darmo.

**Charakter brandu**:
- **Ekspert który dzieli się** (nie agresywny marketer)
- **Hobby project z passion** (nie corporation)
- **Spokojny, profesjonalny, ciepły** (nie hype, nie cringe)
- **Polski-first** (dumnie, ale bez patriotyzmu wykrzyknikowego)
- **Open i transparent** (kod publiczny, decyzje udokumentowane)

## Kolory (do decyzji w sesji)

### Opcje accent color

**a) Ciepły orange/coral** (jak Claude brand)
- Primary: `oklch(0.7 0.18 35)` (ciepły orange `#FF6B4A`-ish)
- Secondary: `oklch(0.65 0.15 25)` (coral `#D97757`-ish)
- **Pro**: nawiązanie do Marcin używa Claude (`Claude Werner` mailbox), spójne z jego ekosystemem
- **Con**: nie ma związku z polskim brandingiem ani Whisper

**b) Polski czerwony** (subtelnie - akcent flagi)
- Primary: `oklch(0.55 0.22 25)` (czerwień flagowa, ale wyciszona, nie "BIAŁOCZERWONI!!!")
- Secondary: cool gray dla balansu
- **Pro**: polskie brandowanie, "polski Whisper"
- **Con**: czerwony może być postrzegany jako alarmowy / agresywny

**c) Neutral monochrome + jeden vivid accent**
- Primary: `oklch(0.95 0.01 250)` (off-white)
- Background: `oklch(0.15 0.01 250)` (deep dark blue-gray)
- Accent: subtle violet `oklch(0.7 0.15 280)` lub teal `oklch(0.7 0.15 190)`
- **Pro**: minimalistyczny, profesjonalny, łatwy do utrzymania
- **Con**: mniej "remembered", bardziej "yet another tech site"

**Rekomendacja**: zapytaj Marcina, ale jeśli musi wybrać agent - `c) Neutral + accent` (najbardziej premium look bez ryzyka cringe).

### Palette (oklch, dark + light obie pełne)

```css
@theme {
  /* Neutrals - cool gray base */
  --color-bg: oklch(0.10 0.005 250);          /* dark default */
  --color-bg-elevated: oklch(0.15 0.005 250);
  --color-fg: oklch(0.95 0.005 250);
  --color-fg-muted: oklch(0.7 0.01 250);
  --color-border: oklch(0.25 0.005 250);
  
  /* Light mode */
  @media (prefers-color-scheme: light) {
    --color-bg: oklch(0.99 0.005 250);
    --color-bg-elevated: oklch(0.96 0.005 250);
    --color-fg: oklch(0.15 0.005 250);
    --color-fg-muted: oklch(0.4 0.01 250);
    --color-border: oklch(0.85 0.005 250);
  }
  
  /* Accent - ZAMIEŃ na wybrany kolor po konsultacji z Marcinem */
  --color-accent: oklch(0.7 0.18 35);          /* placeholder: warm coral */
  --color-accent-hover: oklch(0.65 0.20 35);
  --color-accent-fg: oklch(0.99 0 0);          /* white na accent */
  
  /* Semantic */
  --color-success: oklch(0.65 0.15 145);
  --color-warning: oklch(0.75 0.15 80);
  --color-danger: oklch(0.55 0.20 25);
}
```

### Gradient ideas

- **Hero background**: subtelny mesh gradient z accent → bg
- **CTA button**: linear gradient od accent do accent-hover
- **Section dividers**: prawie niewidoczne `color-mix(in oklch, transparent, var(--color-border) 50%)`

### Color contrast

- **Body text**: 7:1 minimum (WCAG AAA)
- **Large text** (>24px): 4.5:1 minimum (WCAG AA)
- **Interactive elements**: 4.5:1 minimum + visible focus ring
- **Decorative elements**: dowolnie (ale czytelność first)

## Typografia

### Font stack

**Display + body**: jeden font dla spójności (modern trend, mniej HTTP requests):

**Opcja A**: **Inter** (Google Fonts, self-host via next/font)
- **Pro**: wsparcie polskich znaków, świetna czytelność, modern, popular
- **Con**: trochę "yet another tech site"

**Opcja B**: **Lato** (polski designer Łukasz Dziedzic!)
- **Pro**: polski kontekst, ciepły charakter, dobre wsparcie diakrytycznych
- **Con**: starsza, mniej "tech"

**Opcja C**: **Geist** (Vercel's font, free na Vercel)
- **Pro**: modern, zaprojektowany pod tech sites, świetne kerning
- **Con**: nowy, mniej tested w polish

**Rekomendacja**: **Inter Variable** (pełen zakres weight w jednym pliku, lighthouse-friendly).

### Weight scale

```css
font-weight: 400 (regular)  /* body text */
font-weight: 500 (medium)   /* subtitles */
font-weight: 600 (semibold) /* button labels */
font-weight: 700 (bold)     /* section headers */
font-weight: 800-900        /* hero headline only */
```

### Type scale (modular, ratio 1.250 - "Major Third")

```css
--text-xs: 0.75rem;     /* 12px - meta */
--text-sm: 0.875rem;    /* 14px - small */
--text-base: 1rem;      /* 16px - body */
--text-lg: 1.125rem;    /* 18px - large body */
--text-xl: 1.25rem;     /* 20px - subhead */
--text-2xl: 1.5625rem;  /* 25px - h3 */
--text-3xl: 1.953rem;   /* 31px - h2 */
--text-4xl: 2.441rem;   /* 39px - h1 small */
--text-5xl: 3.052rem;   /* 49px - h1 big */
--text-6xl: 3.815rem;   /* 61px - hero small */
--text-7xl: 4.768rem;   /* 76px - hero big */
--text-8xl: 5.96rem;    /* 95px - HERO huge */
```

### Hero headline

Modern style: **giant, tight tracking, mixed weight**:

```css
.hero-headline {
  font-size: clamp(3rem, 10vw, 5.96rem);    /* responsive */
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 0.95;
  text-wrap: balance;
}
```

Przykład: "Mówisz. Piszesz." z każdym słowem w innej weight (`font-variation-settings`).

### Polskie znaki - obowiązkowo

Przed użyciem fontu sprawdź czy ma:
- ą Ą ę Ę ś Ś ć Ć ź Ź ż Ż ó Ó ł Ł ń Ń

W subset: zostaw **latin + latin-ext** (latin-ext zawiera polskie diakrytyczne).

```typescript
// app/fonts.ts
import { Inter } from "next/font/google";

export const inter = Inter({
  subsets: ["latin", "latin-ext"],  // latin-ext = polskie znaki
  variable: "--font-inter",
  display: "swap",
});
```

## Spacing scale

Bazowa jednostka: **4px** (0.25rem). Skala 4-8-16-24-32-48-64-96-128.

```css
--space-1: 0.25rem;   /* 4px */
--space-2: 0.5rem;    /* 8px */
--space-4: 1rem;      /* 16px */
--space-6: 1.5rem;    /* 24px */
--space-8: 2rem;      /* 32px */
--space-12: 3rem;     /* 48px */
--space-16: 4rem;     /* 64px */
--space-24: 6rem;     /* 96px */
--space-32: 8rem;     /* 128px */
```

**Section padding (vertical)**: min 96px desktop, 48px mobile.

## Layout grid

- **Container max-width**: 1280px (`max-w-7xl` w Tailwind)
- **Mobile**: full width, padding 16px
- **Tablet**: 768-1024px, padding 32px
- **Desktop**: 1024-1280px, padding 48px
- **Wide**: >1280px, container centered

## Border radius

```css
--radius-sm: 0.25rem;    /* 4px - small elements */
--radius-md: 0.5rem;     /* 8px - cards */
--radius-lg: 0.75rem;    /* 12px - large cards */
--radius-xl: 1rem;       /* 16px - hero blocks */
--radius-2xl: 1.5rem;    /* 24px - feature cards */
--radius-full: 9999px;   /* pills, circles */
```

**Default dla większości UI**: `--radius-md`.

## Shadows (subtle, never harsh)

```css
--shadow-sm: 0 1px 2px oklch(0 0 0 / 0.05);
--shadow-md: 0 4px 6px oklch(0 0 0 / 0.07);
--shadow-lg: 0 10px 15px oklch(0 0 0 / 0.10);
--shadow-glow: 0 0 24px oklch(var(--color-accent) / 0.3);  /* accent glow */
```

W dark mode redukuj alpha do 0.4 dla widoczności.

## Iconografia

**Library**: **Lucide** (open-source, modern, consistent stroke weight, polski-friendly)

Alternatywa: **Phosphor Icons** (więcej wariantów: thin, light, regular, bold, fill, duotone).

**Stroke width**: 1.5px (default), 2px dla bold sections.

**Size scale**: 16, 20, 24, 32, 48, 64.

## Imagery

### Style

- **Mockupy**: realistyczne (laptop / monitor z apką wyświetloną), nie cartoonish
- **Ilustracje**: geometryczne, soft gradients, nie cluttered
- **Photos**: jeśli używasz, neutral / professional, **nie stockowe smile-business-people**
- **Filtry**: subtle dimming + slight saturation reduce (`filter: saturate(0.9) brightness(0.95)`)

### Format

- **AVIF + WebP** (auto via Vercel Image Optimization)
- **Lazy load** below-fold (browser native)
- **Blurhash placeholder** dla LCP

## Dark mode

**Default**: dark (większość programistów + Marcin lubi dark).

**Override**: respect `prefers-color-scheme` + manual toggle z localStorage persistence.

**Implementation**:
```typescript
// app/layout.tsx
<html lang="pl" suppressHydrationWarning>
  <head>
    <script dangerouslySetInnerHTML={{
      __html: `
        const t = localStorage.getItem('theme') || 'system';
        const dark = t === 'dark' || (t === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
        document.documentElement.classList.toggle('dark', dark);
      `
    }} />
  </head>
  <body className={inter.variable}>{children}</body>
</html>
```

## Tonalność copy (KRYTYCZNE - per Marcin's global rules)

### TAK pisać (✅)

- **Polski język ZAWSZE** z diakrytycznymi (ą, ę, ś, ć, ź, ż, ó, ł, ń)
- **"-" (krótka pauza)** zamiast **"—" (em dash)** - reguła Marcina
- **"Ty" forma**, nie "Państwo", nie 3 osoba
- **Active voice**: "PolskiWhisper przyspiesza pisanie", NIE "Pisanie jest przyspieszane"
- **Krótkie zdania**, pojedyncze idee per zdanie
- **Konkretne liczby**: "3x szybciej", "95% dokładność", "0 PLN"
- **"Co user zyskuje"** framing
- **Ciepły, spokojny ton** - jak ekspert który dzieli się czymś dobrym

### NIE pisać (❌)

- **"rewolucyjny", "innowacyjny", "game-changer"** - banalne, wszyscy używają
- **"AI-powered"** - banał, lepiej "Whisper od OpenAI" (specyfika)
- **"Best in class", "world's leading"** - brzmi jak korporacja
- **ALL CAPS w copy** (poza badge "MIT", "FREE")
- **"Fix", "naprawiony bug"** - per Marcin's tonality, NIE alarmistyczny ton
- **"Krytyczny", "ważne!", "uwaga!"** - to nie jest pożar
- **Emoji w main headlines** (ok w mikro-treściach jak ✓ MIT)
- **Polski bez polskich znaków** ("Czesc", "spojrz") - **niedopuszczalne**

### Tone words (charakter)

- **Spokojny, profesjonalny, ciepły**
- **Confident** bez arrogance
- **Helpful** bez condescending
- **"Hobby project z passion"** vibe, NIE "next billion dollar SaaS"

### Examples

✅ **DOBRE**:
- "Pisz głosem. Po polsku. Za darmo."
- "Po pobraniu modelu, audio nigdy nie opuszcza Twojego komputera."
- "PolskiWhisper to projekt open-source. Możesz audytować kod, modyfikować, używać komercyjnie."
- "Naciśnij hotkey, mów, tekst pojawi się tam gdzie kursor."

❌ **ZŁE**:
- "REWOLUCYJNE narzędzie AI do dyktowania!!!"
- "Best-in-class polish dictation powered by OpenAI's Whisper technology"
- "Zostaw stare metody pisania - PolskiWhisper to przyszłość!"
- "Czesc! Daj nam szanse i zostań naszym klientem juz dzis!"

## Nazewnictwo (decyzja jednorazowa)

- **PolskiWhisper** (jedno słowo, kapitalizacja P + W)
- NIE "Polski Whisper" (oddzielne)
- NIE "polskiwhisper" (lowercase, poza domeną)
- W tytułach OK: **"PolskiWhisper - dyktowanie po polsku offline"**
- W body OK: **"PolskiWhisper przyspiesza pisanie..."**

## Print styles

Podstawowy `@media print`:
- Hide animations
- Show all content (no lazy load placeholders)
- Black text on white background
- Larger font for readability
- URL after links: `a::after { content: " (" attr(href) ")"; }`

## Mikro-detale (polish)

Te rzeczy decydują o "wymaksowaniu":

- **Cursor**: na CTA buttons - subtle pointer animation
- **Selection**: custom `::selection { background: var(--color-accent); color: var(--color-accent-fg); }`
- **Scrollbar**: stylizowany w dark mode (subtle)
- **Focus ring**: NIGDY nie `outline: none` bez visible alternative (a11y)
- **Smooth scroll**: `scroll-behavior: smooth` dla anchor links (respect prefers-reduced-motion)
- **Loading states**: skeleton screens, NIE spinning circle
- **Optimistic UI**: gdzie możliwe (np. mock toggle theme przed actual change)
- **Easter eggs**: Konami code, hidden hover states, loading messages variations
- **Empty states**: jeśli FAQ filter zwraca 0 - friendly message
- **Error states**: nie "Error 500" - "Coś poszło nie tak. Sprawdź internet i odśwież."
- **404 page**: personality, link do home + losowy fact o PolskiWhisper

## Voice & speak summary

Strona ma się czuć jak **rozmowa z ekspertem przy kawie** - konkrety, bez fluffu, z humorem ale nie clownish, z pasją ale nie hype.

**Test**: jeśli czytałbyś copy głośno znajomemu programiście przy kawie - czy by zacisnął zęby z cringe? Jeśli tak - przepisz.
