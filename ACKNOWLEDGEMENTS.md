# Acknowledgements

PolskiWhisper © 2026 Marcin Werner. Wydane na licencji [MIT](LICENSE).

Aplikacja jest budowana z wykorzystaniem niżej wymienionych projektów open source. Jesteśmy wdzięczni ich autorom i kontrybutorom za ich pracę i otwartość.

---

## Komponenty wbudowane (linkowane statycznie)

### WhisperKit
- **Funkcja**: silnik Speech-to-Text na CoreML
- **Copyright**: © 2024 Argmax, Inc.
- **Licencja**: Apache License 2.0
- **Repozytorium**: https://github.com/argmaxinc/WhisperKit

### OpenAI Whisper (model weights)
- **Funkcja**: wagi modelu rozpoznawania mowy (pobierane przez WhisperKit)
- **Copyright**: © 2022 OpenAI
- **Licencja**: MIT
- **Repozytorium**: https://github.com/openai/whisper

### KeyboardShortcuts
- **Funkcja**: obsługa konfigurowalnych globalnych skrótów klawiszowych
- **Copyright**: © Sindre Sorhus
- **Licencja**: MIT
- **Repozytorium**: https://github.com/sindresorhus/KeyboardShortcuts

### LaunchAtLogin-Modern
- **Funkcja**: autostart aplikacji przy logowaniu do macOS
- **Copyright**: © Sindre Sorhus
- **Licencja**: MIT
- **Repozytorium**: https://github.com/sindresorhus/LaunchAtLogin-Modern

### GRDB.swift
- **Funkcja**: wrapper SQLite (lokalna baza danych ustawień)
- **Copyright**: © 2015-2024 Gwendal Roué
- **Licencja**: MIT
- **Repozytorium**: https://github.com/groue/GRDB.swift

### Sparkle (planowane na przyszłą wersję)
- **Funkcja**: framework auto-update dla aplikacji macOS
- **Copyright**: © Sparkle Project
- **Licencja**: MIT
- **Repozytorium**: https://github.com/sparkle-project/Sparkle

---

## Komponenty zewnętrzne (uruchamiane poza aplikacją)

### Ollama
- **Funkcja**: lokalny runtime LLM, wywoływany przez HTTP API
- **Copyright**: © 2023 Ollama
- **Licencja**: MIT
- **Repozytorium**: https://github.com/ollama/ollama
- **Status**: NIE jest bundlowane z aplikacją. Użytkownik instaluje samodzielnie.

### Bielik 11B v2.3 (domyślny LLM dla post-processingu, opcjonalny)
- **Funkcja**: polski model językowy do post-processingu transkrypcji
- **Copyright**: © SpeakLeash
- **Licencja**: Apache License 2.0
- **Strona modelu**: https://huggingface.co/speakleash/Bielik-11B-v2.3-Instruct
- **Status**: NIE jest bundlowane. Użytkownik pobiera przez Ollama (`ollama pull SpeakLeash/bielik-11b-v2.3-instruct:Q4_K_M`).

### Inne modele LLM (do wyboru w ustawieniach)
- **llama-3.2:3b-instruct** - © Meta Platforms, licencja Llama 3.2 Community License
- **phi-3.5:3.8b** - © Microsoft, licencja MIT
- **qwen-2.5:14b-instruct** - © Alibaba Cloud, licencja Apache 2.0
- Wszystkie pobierane przez Ollama, nie bundlowane.

---

## Czcionki i ikony systemowe

PolskiWhisper używa systemowych czcionek (San Francisco) i ikon (SF Symbols) zapewnianych przez macOS. Te zasoby są własnością Apple Inc. i są używane zgodnie z warunkami systemu.

---

## Twórca aplikacji

**Marcin Werner** - autor i utrzymujący

PolskiWhisper jest projektem osobistym, rozwijanym po godzinach jako prezent dla polskojęzycznej społeczności macOS. Każdy może go używać, modyfikować i dystrybuować zgodnie z [MIT License](LICENSE).

---

## Jeśli używasz PolskiWhisper

Nie musisz nic - to MIT. Ale jeśli chcesz, daj gwiazdkę na GitHub i podziel się z innymi Polakami. Szczęścia w dyktowaniu.
