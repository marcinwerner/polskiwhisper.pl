import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";
import "./globals.css";

const inter = Inter({
  subsets: ["latin", "latin-ext"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "PolskiWhisper - dyktowanie po polsku offline",
    template: "%s | PolskiWhisper",
  },
  description:
    "Darmowa, otwartoźródłowa aplikacja do dyktowania głosowego po polsku. Działa offline na macOS i Windows. Zero telemetrii, kod publiczny, MIT.",
  metadataBase: new URL(
    process.env.NEXT_PUBLIC_SITE_URL ?? "https://polskiwhisper.pl"
  ),
  alternates: { canonical: "/" },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  openGraph: {
    title: "PolskiWhisper - dyktowanie po polsku offline",
    description:
      "Darmowa aplikacja do dyktowania w macOS i Windows. Mowa jest 3× szybsza niż klawiatura. Działa offline, zero telemetrii.",
    url: "https://polskiwhisper.pl",
    type: "website",
    locale: "pl_PL",
    siteName: "PolskiWhisper",
  },
  twitter: {
    card: "summary_large_image",
    title: "PolskiWhisper - dyktowanie po polsku offline",
    description:
      "Darmowa aplikacja do dyktowania po polsku. 3× szybciej niż klawiatura. macOS · Windows · offline.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pl" className={inter.variable} suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('theme');var d=t==='dark'||(t!=='light'&&matchMedia('(prefers-color-scheme:dark)').matches);document.documentElement.classList.toggle('light',!d)}catch(e){}})()`,
          }}
        />
      </head>
      <body className="min-h-dvh font-sans antialiased">
        <a href="#main" className="skip-to-content">
          Przejdź do treści
        </a>
        {children}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
