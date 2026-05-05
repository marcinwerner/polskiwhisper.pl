# Instalacja PolskiWhisper

## Wymagania

- **macOS 14 Sonoma** lub nowszy
- **Apple Silicon** (M1/M2/M3/M4 - Intel nie jest wspierany)
- **8 GB RAM** minimum (16 GB dla komfortowej pracy z modelem AI)
- **2 GB wolnego miejsca** na dysku (model Whisper Turbo: ~547 MB + cache + audio)
- **Mikrofon** (wbudowany lub zewnętrzny)

## Krok 1: Pobranie

Pobierz najnowszy `PolskiWhisper-X.Y.Z.dmg` ze strony [Releases](https://github.com/marcinwerner/polskiwhisper.pl/releases) na GitHub.

## Krok 2: Instalacja

1. Otwórz pobrany plik `.dmg` (dwuklik w Finderze)
2. **Przeciągnij** ikonę PolskiWhisper na ikonę Applications
3. Zamknij okno DMG i wysuń go z Findera (prawy klik → **Wysuń**)

## Krok 3: Pierwsze uruchomienie - omijamy warning

Aplikacja **nie jest podpisana certyfikatem Apple Developer** (autor zdecydował nie kupować $99/rok). macOS pokaże warning przy pierwszym uruchomieniu - to **normalne** dla aplikacji distribuowanych poza Mac App Store.

### Sposób 1 (najprostszy) - prawy klik → Otwórz

1. Otwórz **Aplikacje** w Finderze
2. **Right-click** (lub Ctrl+klik) na `PolskiWhisper.app`
3. Wybierz **Otwórz**
4. Pojawi się dialog: *"PolskiWhisper to aplikacja pobrana z internetu. Czy na pewno chcesz ją otworzyć?"*
5. Kliknij **Otwórz**
6. Aplikacja uruchomi się, nigdy więcej nie będzie pytać

### Sposób 2 - Ustawienia systemu

Jeśli sposób 1 nie zadziałał:

1. Spróbuj uruchomić PolskiWhisper normalnie (dwuklik) → zobaczysz warning, **anuluj**
2. Otwórz **Ustawienia systemu → Prywatność i ochrona**
3. Przewiń w dół do sekcji "Bezpieczeństwo"
4. Zobaczysz: *"PolskiWhisper została zablokowana ponieważ nie pochodzi od zidentyfikowanego deweloperów"*
5. Kliknij **Otwórz mimo to**
6. Potwierdź w dialogu

## Krok 4: Pierwszy onboarding

Po uruchomieniu aplikacja przeprowadzi Cię przez konfigurację (6 kroków):

1. **Powitanie** - opis aplikacji
2. **Mikrofon** - zezwól na dostęp (system pokaże prompt)
3. **Dostępność** - **kluczowe** dla auto-paste i hotkey:
   - Otwórz **Ustawienia systemu → Prywatność i ochrona → Dostępność**
   - **Przeciągnij** PolskiWhisper z folderu Aplikacje do listy
   - Włącz przełącznik
   - Wróć do onboardingu, kliknij "Sprawdź ponownie"
4. **Model AI** - aplikacja pobierze Whisper Turbo (~547 MB, 1-2 minuty)
5. **Skrót klawiszowy** - default Lewy Option (zmienialny w Ustawieniach)
6. **Gotowe** - możesz dyktować

## Krok 5: Test

1. Otwórz **Notatki**, kliknij w pole tekstowe
2. **Tap** lewy Option (krótkie naciśnięcie)
3. Powiedz coś po polsku (np. "Cześć, to jest test polskiego dyktowania")
4. **Tap** lewy Option ponownie
5. W ciągu ~1-2s tekst pojawia się w Notatkach

## Konfiguracja

Po instalacji aplikacja działa w pasku menu (ikona mikrofonu w prawym górnym rogu).

- **Cmd+,** lub menu bar → "Otwórz Ustawienia..." aby zmienić:
  - Hotkey (5 opcji + tryb toggle/przytrzymanie)
  - Model Whisper (7 opcji od 75 MB do 3 GB)
  - Włączyć opcjonalne oczyszczanie tekstu przez AI (Bielik 11B)
  - Słownictwo własne (boost rozpoznawania nazw, find&replace)
  - Dźwięki, max czas nagrywania, autostart przy logowaniu

## Najczęstsze problemy

### "Hotkey nie działa, tap nic nie robi"
→ Sprawdź **Ustawienia systemu → Prywatność i ochrona → Dostępność**. PolskiWhisper musi być na liście **z włączonym przełącznikiem**.

### "Tekst się nie wkleja, jest tylko w schowku"
→ Brak Accessibility (jak wyżej) **albo** docelowa aplikacja blokuje synthetic Cmd+V (rzadkie - próbuj w Notatkach).

### "Nie widzę ikony w pasku menu"
→ Może być ukryta w Centrum sterowania (prawy górny róg, ikona przełączników) lub przez Bartender/iStat. Sprawdź też czy aplikacja jest uruchomiona (Cmd+Tab).

### "Każde nagrywanie wkleja 'Dzięki za oglądanie'" / inne dziwne frazy
→ To halucynacja Whispera (model trenowany na YouTube subtitles). Aplikacja ma filter ale czasem przepuszcza. Mów wyraźnie i głośniej.

### "Pierwszy raz pobiera model 547 MB - długo trwa"
→ Normalne. Pobiera się **raz**. Kolejne uruchomienia ładują z cache (~3-5 sekund).

### "Aplikacja zaczęła się dziwnie zachowywać"
→ Settings → O programie → "Resetuj wszystkie ustawienia". Słownik i pobrane modele NIE zostaną usunięte.

## Odinstalowanie

1. Zamknij PolskiWhisper (menu bar → "Zakończ")
2. Usuń `PolskiWhisper.app` z folderu Aplikacje (do Kosza)
3. Opcjonalnie usuń pliki:
   - `~/Library/Application Support/PolskiWhisper/` - słownik
   - `~/Library/Caches/PolskiWhisper/` - tymczasowe nagrania
   - `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930_547MB/` - model AI (~547 MB)
   - `~/Library/Preferences/pl.polskiwhisper.app.plist` - preferencje

## Wsparcie

- [GitHub Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues) - bug reporty i feature requesty
- [GitHub Discussions](https://github.com/marcinwerner/polskiwhisper.pl/discussions) - pytania, sugestie
- [Polityka prywatności](PRIVACY.md) - zero telemetrii, audytowalny kod
