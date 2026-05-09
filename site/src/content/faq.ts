export const FAQ_ITEMS = [
  {
    question: "Czy to naprawdę darmowe?",
    answer:
      "Tak, na zawsze. Aplikacja jest open-source na licencji MIT. Możesz pobrać, używać, modyfikować, dystrybuować - bez kosztów, bez rejestracji, bez konta.",
  },
  {
    question: "Co z prywatnością?",
    answer:
      "Po pobraniu modelu Whisper (~1.5 GB, jednorazowo) aplikacja działa w pełni offline. Twoje audio nigdy nie opuszcza komputera. Nie zbieramy żadnych danych. Nie ma analytics, telemetrii, phone-home. Kod jest publiczny - możesz audytować co dokładnie aplikacja robi.",
  },
  {
    question: "Jak dokładne są transkrypcje?",
    answer:
      "Z domyślnym modelem Whisper Turbo (1.5 GB) dokładność dla polskiego wynosi około 95% słów poprawnych. Aplikacja ma wbudowany filtr halucynacji - usuwa typowe artefakty Whisper.",
  },
  {
    question: "Czy są naukowe potwierdzenia że dyktowanie jest szybsze?",
    answer:
      'Tak. Badanie Stanford / Baidu / University of Washington z 2016 roku (Ruan, Wobbrock, Liou, Ng, Landay) wykazało że mowa jest 3.0× szybsza niż klawiatura dla angielskiego i 2.8× dla mandaryńskiego, przy 20.4% niższym wskaźniku błędów. Badanie objęło 32 osoby, każda przepisywała 100 typowych fraz. Pełny paper: arxiv.org/abs/1608.07323.',
  },
  {
    question: "Jakie języki obsługuje?",
    answer:
      "Whisper rozumie około 100 języków, ale aplikacja jest zoptymalizowana pod polski. Chcesz angielski? Zmień model w ustawieniach.",
  },
  {
    question: "Czy potrzebuję GPU?",
    answer:
      "Mac: Apple Silicon (M1/M2/M3/M4) jest wymagany - aplikacja wykorzystuje Apple Neural Engine. Windows: GPU z DirectX 12 jest opcjonalne (DirectML acceleration). Bez GPU działa, ale wolniej.",
  },
  {
    question: "Mogę używać w pracy?",
    answer:
      "Tak. Licencja MIT pozwala na użycie komercyjne, modyfikację, dystrybucję - z zachowaniem informacji o autorze i licencji.",
  },
  {
    question: "Dlaczego nie ma w App Store ani Microsoft Store?",
    answer:
      "Bo to hobby project - dystrybucja przez GitHub Releases jest tańsza i bardziej transparentna. Certyfikaty developerskie kosztują, a każdy może audytować kod bezpośrednio.",
  },
  {
    question: "Co jeśli znajdę problem?",
    answer:
      "Otwórz issue na GitHub. Możesz pisać po polsku. Staramy się odpowiadać szybko.",
  },
] as const;
