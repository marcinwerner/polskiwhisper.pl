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
    index: false,
    follow: false,
    nocache: true,
    googleBot: {
      index: false,
      follow: false,
      noimageindex: true,
    },
  },
  openGraph: {
    title: "PolskiWhisper",
    description: "Pisz głosem. Po polsku. Za darmo.",
    type: "website",
    locale: "pl_PL",
    siteName: "PolskiWhisper",
  },
  twitter: {
    card: "summary_large_image",
    title: "PolskiWhisper",
    description: "Pisz głosem. Po polsku.",
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
