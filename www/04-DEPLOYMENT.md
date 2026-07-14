# 04 - DEPLOYMENT: Vercel + DNS + Monitoring

**Cel**: kompletny przepis na wdrożenie polskiwhisper.pl na Vercelu.

---

## Repository setup

### Lokalizacja kodu - dwie opcje (decyzja Marcina, pytanie 7g w 01-BRIEF.md)

**Opcja A - kod w tym repo (rekomendowane)**:
- Lokalizacja: `polskiwhisper.pl/www/site/` (kod) + `polskiwhisper.pl/www/*.md` (brief)
- Vercel: deploy z subdirectory `www/site`, Root Directory ustawiana w project settings
- Git: ten sam repo co apka, jeden CHANGELOG, prostsze
- CI: branch protection per path (np. zmiany w `www/**` triggerują landing build)

**Opcja B - osobny repo**:
- Lokalizacja: osobny repo `polskiwhisper-landing` (nazwa wymaga akceptacji Marcina)
- Vercel: standardowy deploy z root
- Git: osobne historie, niezależne release cycle
- CI: prostsze (single-purpose workflow)

### Konwencja nazewnictwa (jeśli osobny repo)

**Repo**: `polskiwhisper-landing` - **propozycja**, Marcin musi zaakceptować przed utworzeniem (per global rule "PYTAJ O ZGODĘ NA KLUCZOWE NAZWY").

### Inicjalizacja (warianty per opcja A/B)

**Opcja A** (kod w tym repo, `polskiwhisper.pl/www/site/`):

```bash
# Z working dir = polskiwhisper.pl/
mkdir -p www/site
cd www/site

# Reszta jak poniżej (npx create-next-app...)
```

**Opcja B** (osobny repo `polskiwhisper-landing`):

```bash
mkdir -p ~/Documents/GitHub/polskiwhisper-landing
cd ~/Documents/GitHub/polskiwhisper-landing

# Next.js 15 + Tailwind v4 + TypeScript
npx create-next-app@latest . \
  --typescript \
  --tailwind \
  --app \
  --turbopack \
  --eslint \
  --src-dir false \
  --import-alias "@/*" \
  --no-experimental-app

# Tailwind v4 jeszcze nie jest default w create-next-app, więc:
npm install tailwindcss@next @tailwindcss/postcss@next

# Animacje
npm install motion gsap @gsap/react

# Vercel
npm install @vercel/og @vercel/analytics @vercel/speed-insights @vercel/kv
npm install -D @vercel/style-guide

# UI
npm install lucide-react clsx tailwind-merge
npm install -D @types/node @types/react

# Optional: shadcn/ui dla bazowych komponentów
npx shadcn@latest init

# Testing
npm install -D vitest @testing-library/react @testing-library/jest-dom
npm install -D @playwright/test

# Whisper demo (jeśli implementujesz)
npm install @xenova/transformers  # albo @huggingface/transformers
```

### Repository structure

```
polskiwhisper-landing/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── (marketing)/
│   │   ├── privacy/page.tsx
│   │   └── download/page.tsx
│   └── api/
│       ├── og/route.tsx
│       ├── github-stats/route.ts
│       └── transcribe/route.ts
├── components/
│   ├── hero/
│   ├── demo/
│   ├── calculator/
│   ├── how-it-works/
│   ├── use-cases/
│   ├── privacy/
│   ├── download/
│   ├── roadmap/
│   ├── faq/
│   ├── footer/
│   └── shared/
├── lib/
│   ├── github.ts
│   ├── analytics.ts
│   ├── motion.ts
│   └── whisper-client.ts
├── content/
│   ├── faq.ts
│   ├── use-cases.ts
│   └── roadmap.ts
├── public/
│   ├── videos/
│   ├── fonts/
│   └── icons/
├── docs/
│   ├── DECISIONS.md      # Mini ADR-y
│   └── screenshots/
├── tests/
│   ├── e2e/
│   └── unit/
├── .env.example
├── .env.local            # (gitignored)
├── next.config.mjs
├── tailwind.config.ts    # (lub @theme w CSS dla v4)
├── tsconfig.json
├── package.json
├── README.md
├── CONTRIBUTING.md
└── LICENSE               # MIT
```

## Vercel project setup

### 1. Connect repo

```bash
# W lokalnym repo
git init
git add .
git commit -m "feat: initial scaffold"
gh repo create polskiwhisper-landing --public --source=. --push

# Albo manual:
# 1. Stwórz repo na github.com
# 2. git remote add origin git@github.com:marcinwerner/polskiwhisper-landing.git
# 3. git push -u origin main
```

### 2. Import do Vercel

```bash
# CLI
npx vercel link
npx vercel  # pierwsze deploy

# Albo przez UI:
# https://vercel.com/new → Import Git Repository → polskiwhisper-landing
```

### 3. Environment variables

Vercel project settings → Environment Variables:

| Klucz | Wartość | Environment |
|-------|---------|-------------|
| `GITHUB_TOKEN` | fine-grained PAT, scope `public_repo:read` | Production, Preview |
| `KV_REST_API_URL` | (auto z Vercel KV setup) | Production, Preview, Development |
| `KV_REST_API_TOKEN` | (auto z Vercel KV setup) | Production, Preview, Development |
| `KV_REST_API_READ_ONLY_TOKEN` | (auto) | Production, Preview, Development |
| `NEXT_PUBLIC_SITE_URL` | `https://polskiwhisper.pl` (prod) / preview URL | Per environment |

**WAŻNE**: `GITHUB_TOKEN` to NIE Marcin's main token. Stwórz fine-grained PAT z minimal scope (tylko `public_repo:read` + `metadata:read`).

**Storage secretu** (per Marcin's global rule):
- NIE w repo, NIE w `.env.local` commitowanym
- Vercel Dashboard → Environment Variables (encrypted at rest)
- Lokalnie: `~/mcp-keys/polskiwhisper-landing.env` (chmod 600) + `source` przed dev

### 4. Vercel KV setup

```bash
# Z Vercel CLI
vercel kv create polskiwhisper-cache
vercel kv link polskiwhisper-cache
# To automatycznie dodaje KV_* env vars do projektu
```

Użycie w kodzie:

```typescript
// lib/github.ts
import { kv } from "@vercel/kv";

export async function getGithubStats() {
  const cached = await kv.get<GithubStats>("github-stats");
  if (cached) return cached;
  
  const fresh = await fetchFromGithubAPI();
  await kv.set("github-stats", fresh, { ex: 300 }); // 5 min TTL
  return fresh;
}
```

### 5. Vercel Cron (opcjonalne, dla refresh)

`vercel.json`:

```json
{
  "crons": [
    {
      "path": "/api/refresh-github-stats",
      "schedule": "0 */6 * * *"
    }
  ]
}
```

API endpoint odświeża cache co 6h.

## DNS configuration

### Domena polskiwhisper.pl (prawdopodobnie u Marcina w lh.pl lub Cloudflare)

**Sprawdź najpierw**: `dig NS polskiwhisper.pl` - kto trzyma DNS.

### Opcja A: Vercel native DNS

```
# W Vercel project → Settings → Domains
# Add: polskiwhisper.pl
# Vercel pokaże DNS records do dodania (A + CNAME)
# Marcin musi je dodać u providera DNS

# Records:
# polskiwhisper.pl     A     76.76.21.21
# www.polskiwhisper.pl CNAME cname.vercel-dns.com
```

### Opcja B: Cloudflare jako proxy (rekomendowane)

**Korzyści Cloudflare**:
- Edge caching (poza Vercel edge)
- DDoS protection
- Analytics (privacy-first)
- Free tier wystarczy
- Marcin używa Cloudflare w innych projektach

**Setup**:
1. W Cloudflare → Add site `polskiwhisper.pl`
2. Update nameservers u registrara (lh.pl) na CF
3. W CF DNS:
   ```
   polskiwhisper.pl       A     76.76.21.21    (Proxied: yes)
   www.polskiwhisper.pl   CNAME cname.vercel-dns.com (Proxied: yes)
   ```
4. CF SSL: Full (strict) - Vercel ma SSL, CF ma SSL, end-to-end TLS
5. CF Page Rules:
   - `www.polskiwhisper.pl/*` → 301 redirect to `polskiwhisper.pl/$1`
6. CF Caching:
   - Browser cache TTL: respect existing headers
   - Edge cache TTL: standard

### Opcja C: Direct Vercel + redirect www→apex

W Vercel:
- Add `polskiwhisper.pl` as primary
- Add `www.polskiwhisper.pl` as redirect to apex

DNS:
```
polskiwhisper.pl       A     76.76.21.21
www.polskiwhisper.pl   CNAME cname.vercel-dns.com
```

**Rekomendacja**: **Opcja B (Cloudflare)** - daje najwięcej kontroli, najlepszy performance global, free tier.

**Pytanie do Marcina**: per AUDIT-PROPOSE-WAIT-EXECUTE - sprawdź najpierw co aktualnie jest dla polskiwhisper.pl, zaproponuj plan, czekaj na OK.

## CI/CD Setup

### GitHub Actions

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run type-check

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm test

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run test:e2e

  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - uses: treosh/lighthouse-ci-action@v11
        with:
          urls: |
            http://localhost:3000
          uploadArtifacts: true
          temporaryPublicStorage: true
          configPath: ./.lighthouserc.json
```

`.lighthouserc.json`:

```json
{
  "ci": {
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.95 }],
        "categories:accessibility": ["error", { "minScore": 0.95 }],
        "categories:best-practices": ["error", { "minScore": 1.0 }],
        "categories:seo": ["error", { "minScore": 1.0 }]
      }
    }
  }
}
```

### Vercel Preview Deployments

Auto na każdy PR:
- URL: `polskiwhisper-landing-git-<branch>-<team>.vercel.app`
- Komentarz w PR od Vercel bota
- Preview comments (notatki w preview UI)

### Branch protection

Settings → Branches → main:
- Require pull request before merging
- Require status checks: lint + test + e2e + lighthouse
- Require branches to be up to date
- Include administrators

## Monitoring

### Vercel Analytics (privacy-first)

```typescript
// app/layout.tsx
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
```

**Co mierzy**:
- Page views (anonymized, no cookies, GDPR-friendly)
- Web Vitals (LCP, INP, CLS, TTFB)
- Geographic distribution
- Top pages, referrers
- Custom events (np. "download_click_macos")

**NIE mierzy**:
- Personal data
- Cross-site tracking
- IP addresses (hashed)

### Sentry (opcjonalnie - jeśli chcesz error tracking)

```bash
npm install @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

**Free tier**: 5k errors/month, wystarczy na hobby project.

### UptimeRobot (free)

Monitor: `https://polskiwhisper.pl`
- Interval: 5 min
- Alert email: kontakt@marcinwerner.com
- Free tier wystarczy

## SEO setup

### `app/sitemap.ts`

```typescript
import { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://polskiwhisper.pl",
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1.0,
    },
    {
      url: "https://polskiwhisper.pl/privacy",
      lastModified: new Date(),
      changeFrequency: "monthly",
      priority: 0.5,
    },
    {
      url: "https://polskiwhisper.pl/download",
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 0.9,
    },
  ];
}
```

### `app/robots.ts`

```typescript
import { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
    },
    sitemap: "https://polskiwhisper.pl/sitemap.xml",
  };
}
```

### Metadata + JSON-LD

```typescript
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    default: "PolskiWhisper - dyktowanie po polsku offline",
    template: "%s | PolskiWhisper",
  },
  description: "Darmowa, otwartoźródłowa aplikacja do dyktowania głosowego po polsku. Działa offline na macOS. Zero telemetrii, kod publiczny, MIT.",
  metadataBase: new URL("https://polskiwhisper.pl"),
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "PolskiWhisper",
    description: "Pisz głosem. Po polsku. Za darmo.",
    type: "website",
    locale: "pl_PL",
    siteName: "PolskiWhisper",
    images: [{ url: "/api/og", width: 1200, height: 630 }],
  },
  twitter: {
    card: "summary_large_image",
    title: "PolskiWhisper",
    description: "Pisz głosem. Po polsku.",
    images: ["/api/og"],
  },
  icons: {
    icon: "/favicon.ico",
    apple: "/apple-touch-icon.png",
  },
};
```

JSON-LD w page:

```typescript
const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "PolskiWhisper",
  operatingSystem: ["macOS"],
  applicationCategory: "ProductivityApplication",
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "PLN",
  },
  aggregateRating: {
    "@type": "AggregateRating",
    ratingValue: "4.8",
    ratingCount: "12",
  },
};
```

## OG Image (dynamic)

`app/api/og/route.tsx`:

```typescript
import { ImageResponse } from "next/og";

export const runtime = "edge";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const version = searchParams.get("v") || "0.1.5";

  return new ImageResponse(
    (
      <div style={{
        height: "100%",
        width: "100%",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        background: "linear-gradient(135deg, #0a0a0a, #1a1a1a)",
        color: "white",
      }}>
        <h1 style={{ fontSize: 80, fontWeight: 800 }}>
          PolskiWhisper
        </h1>
        <p style={{ fontSize: 32, marginTop: 20 }}>
          Pisz głosem. Po polsku. v{version}
        </p>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  );
}
```

## Performance optimization

### Critical optimization checklist

- [ ] **Fonts**: `next/font` z `display: swap` + subset latin-ext
- [ ] **Images**: `next/image` wszędzie, AVIF/WebP auto, blurhash placeholder
- [ ] **Videos**: lazy load + `playsinline` + `muted` autoplay (loop demo)
- [ ] **Lazy components**: `dynamic()` dla heavy components (3D scenes, WebGPU demo)
- [ ] **Code splitting**: per route automatycznie + manual `dynamic()` dla below-fold
- [ ] **Tree shaking**: import z `lucide-react` per icon, nie cały package
- [ ] **Bundle analyzer**: `@next/bundle-analyzer` w build do weryfikacji
- [ ] **Caching headers**: static assets `immutable, max-age=31536000`
- [ ] **HTTP/3**: auto via Vercel
- [ ] **Compression**: brotli auto via Vercel
- [ ] **Speculation Rules**: prefetch download links na hover

### Bundle target

- **Initial JS**: < 100 kB gzipped
- **Initial CSS**: < 30 kB
- **First Load JS** (per route): < 200 kB

Sprawdzaj po każdym dużym addzie:

```bash
npm run build
# Output pokaże First Load JS per route
```

## Pre-launch checklist

Przed pierwszym push do prod:

- [ ] DNS configured (apex + www → apex redirect)
- [ ] SSL active (CF + Vercel)
- [ ] Sitemap accessible at `/sitemap.xml`
- [ ] Robots.txt accessible at `/robots.txt`
- [ ] OG image renders w Twitter Validator + Facebook Debugger
- [ ] Lighthouse 95+ wszystkie 4 metryki
- [ ] Tested w Chrome / Safari / Firefox / Edge
- [ ] Tested mobile (iPhone 12 / Android mid-range)
- [ ] A11y audit (axe DevTools, 0 critical issues)
- [ ] Reduced motion respected
- [ ] Dark + light mode obie pełne
- [ ] All download links pointing to latest GitHub release
- [ ] FAQ pokrywa top 10 pytań
- [ ] Footer: GitHub link, email, MIT license note
- [ ] Privacy policy linkowana
- [ ] Analytics fires events poprawnie
- [ ] 404 page custom z personality
- [ ] Error boundaries z friendly fallback

## Post-launch

### Monitoring po launch

- **Day 1**: sprawdź Vercel Analytics co 30 min - pageviews, errors, CWV
- **Week 1**: dziennie - czy nie ma 500 errorów, jakie referrery, top pages
- **Month 1**: tygodniowo - trends, conversion (download click %)

### Iteracje

- **v1.1**: feedback z week 1 (poprawki copy, mikro-UX)
- **v1.2**: nowe sekcje (testimonials jeśli pojawią się), case studies
- **v2.0**: i18n EN, dodatkowe języki (jeśli interest)

## Rollback plan

Vercel ma natywny rollback:
- Project → Deployments → wybierz poprzednią → Promote to Production
- Albo CLI: `vercel rollback`

Jeśli DNS-level: zmień A record back na placeholder hosting.

## Cost estimate

**Vercel**:
- **Hobby plan** (free): wystarczy na start (100 GB bandwidth, 100 build min/day)
- **Pro plan** ($20/mo): jeśli przekroczysz - więcej bandwidth, KV więcej requestów
- **Estimate**: hobby project = free tier wystarczy chyba że strona ma >10k visits/day

**Cloudflare**: free tier wystarczy.

**Domain**: zależy od provider, lh.pl ~50 PLN/rok.

**Total month**: 0-20 USD w zależności od traffic.

## Decyzje wymagające akceptacji Marcina (przed implementacją)

Per AUDIT-PROPOSE-WAIT-EXECUTE:

- **a)** **Nazwa repo**: `polskiwhisper-landing` - OK?
- **b)** **DNS provider**: Cloudflare (rekomendacja) czy Vercel native?
- **c)** **Vercel plan**: Hobby (free) na start, Pro później jeśli traffic? - OK?
- **d)** **GitHub PAT**: stworzy Marcin (fine-grained, minimal scope) czy ja? Jeśli ja - explicit instructions co tworzyć
- **e)** **Sentry / error tracking**: tak / nie?
- **f)** **CF account**: nowy czy istniejący Marcin's CF account?
