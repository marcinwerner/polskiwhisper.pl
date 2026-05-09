import type { Metadata } from "next";
import { Navbar } from "@/components/shared/Navbar";
import { Footer } from "@/components/footer/Footer";

export const metadata: Metadata = {
  title: "Polityka prywatności",
  description:
    "PolskiWhisper nie zbiera żadnych danych. Twoje audio nigdy nie opuszcza komputera.",
};

export default function PrivacyPage() {
  return (
    <>
      <Navbar />
      <main
        id="main"
        className="mx-auto max-w-3xl px-4 pb-20 pt-32 sm:px-6 lg:px-8"
      >
        <h1 className="text-3xl font-bold sm:text-4xl">
          Polityka prywatności
        </h1>
        <p className="mt-4 text-[var(--color-fg-muted)]">
          Ostatnia aktualizacja: 9 maja 2026
        </p>

        <div className="prose-custom mt-10 space-y-8 text-[var(--color-fg-muted)]">
          <section>
            <h2 className="text-xl font-semibold text-[var(--color-fg)]">
              Zasada zerowego zbierania danych
            </h2>
            <p className="mt-3 leading-relaxed">
              PolskiWhisper nie zbiera, nie przechowuje i nie przesyła żadnych
              danych osobowych ani danych użytkowania. Aplikacja działa w
              pełni offline po pobraniu modelu.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-fg)]">
              Audio
            </h2>
            <p className="mt-3 leading-relaxed">
              Twoje nagrania głosowe są przetwarzane wyłącznie lokalnie na
              Twoim komputerze przez model Whisper. Żadne audio nie jest
              wysyłane na zewnętrzne serwery. Po transkrypcji dane audio są
              usuwane z pamięci.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-fg)]">
              Model
            </h2>
            <p className="mt-3 leading-relaxed">
              Model Whisper jest pobierany jednorazowo z Hugging Face przy
              pierwszym uruchomieniu i przechowywany lokalnie. Pobieranie
              modelu to jedyny moment, w którym aplikacja wymaga połączenia z
              internetem.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-fg)]">
              Telemetria
            </h2>
            <p className="mt-3 leading-relaxed">
              PolskiWhisper nie zawiera żadnej telemetrii, analityki ani
              mechanizmów śledzenia. Nie rejestrujemy crashy, nie zbieramy
              statystyk użytkowania, nie wysyłamy żadnych danych w tle.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-fg)]">
              Strona internetowa
            </h2>
            <p className="mt-3 leading-relaxed">
              Ta strona (polskiwhisper.pl) korzysta z Vercel Analytics do
              podstawowych statystyk odwiedzin. Analytics nie używa cookies i
              nie śledzi użytkowników między stronami. Dane są anonimowe i
              agregowane.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-fg)]">
              Kod źródłowy
            </h2>
            <p className="mt-3 leading-relaxed">
              Cały kod aplikacji jest publiczny i audytowalny. Możesz
              samodzielnie zweryfikować, że aplikacja nie zbiera żadnych
              danych, przeglądając{" "}
              <a
                href="https://github.com/marcinwerner/polskiwhisper.pl"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent underline decoration-accent/30 transition-colors hover:decoration-accent"
              >
                repozytorium na GitHub
              </a>
              .
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--color-fg)]">
              Kontakt
            </h2>
            <p className="mt-3 leading-relaxed">
              Pytania dotyczące prywatności -{" "}
              <a
                href="mailto:kontakt@marcinwerner.com"
                className="text-accent underline decoration-accent/30 transition-colors hover:decoration-accent"
              >
                kontakt@marcinwerner.com
              </a>
            </p>
          </section>
        </div>
      </main>
      <Footer />
    </>
  );
}
