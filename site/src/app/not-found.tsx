import { Navbar } from "@/components/shared/Navbar";
import { Footer } from "@/components/footer/Footer";

export default function NotFound() {
  return (
    <>
      <Navbar />
      <main
        id="main"
        className="flex min-h-[70vh] flex-col items-center justify-center px-4 text-center"
      >
        <p className="text-8xl font-extrabold text-accent">404</p>
        <h1 className="mt-4 text-2xl font-bold sm:text-3xl">
          Tej strony nie ma
        </h1>
        <p className="mt-3 text-[var(--color-fg-muted)]">
          Ale PolskiWhisper jest - i czeka na Twój głos.
        </p>
        <a
          href="/"
          className="mt-8 inline-flex h-12 items-center gap-2 rounded-xl bg-accent px-6 text-base font-semibold text-[var(--color-accent-fg)] transition-all hover:bg-accent-hover active:scale-[0.98]"
        >
          Wróć na stronę główną
        </a>
      </main>
      <Footer />
    </>
  );
}
