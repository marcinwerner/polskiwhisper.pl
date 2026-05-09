import { Navbar } from "@/components/shared/Navbar";
import { Hero } from "@/components/hero/Hero";
import { Calculator } from "@/components/calculator/Calculator";
import { HowItWorks } from "@/components/how-it-works/HowItWorks";
import { UseCases } from "@/components/use-cases/UseCases";
import { Privacy } from "@/components/privacy/Privacy";
import { WhisperDemo } from "@/components/demo/WhisperDemo";
import { Download } from "@/components/download/Download";
import { Roadmap } from "@/components/roadmap/Roadmap";
import { FAQ } from "@/components/faq/FAQ";
import { Community } from "@/components/community/Community";
import { Footer } from "@/components/footer/Footer";

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "PolskiWhisper",
  description:
    "Darmowa, otwartoźródłowa aplikacja do dyktowania głosowego po polsku. Działa offline na macOS i Windows.",
  operatingSystem: ["macOS", "Windows"],
  applicationCategory: "ProductivityApplication",
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "PLN",
  },
  author: {
    "@type": "Person",
    name: "Marcin Werner",
  },
  license: "https://opensource.org/licenses/MIT",
  url: "https://polskiwhisper.pl",
  downloadUrl:
    "https://github.com/marcinwerner/polskiwhisper.pl/releases/latest",
  softwareVersion: "0.1.5",
  inLanguage: "pl",
};

export default function Home() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <Navbar />
      <main id="main">
        <Hero />
        <Calculator />
        <HowItWorks />
        <UseCases />
        <Privacy />
        <WhisperDemo />
        <Download />
        <Roadmap />
        <FAQ />
        <Community />
      </main>
      <Footer />
    </>
  );
}
