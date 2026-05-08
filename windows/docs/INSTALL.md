# Instalacja PolskiWhisper na Windows

## Wymagania systemowe

- **Windows 10 1809+** lub **Windows 11**
- **~4 GB RAM** wolnego
- **~2 GB miejsca na dysku** (dla modelu Whisper Turbo)
- **Mikrofon** (wbudowany lub zewnętrzny)
- *(opcjonalnie)* GPU z DirectX 12 dla DirectML acceleration

## Pobranie

1. Otwórz [Releases](https://github.com/marcinwerner/polskiwhisper.pl/releases)
2. Pobierz najnowszy plik z prefixem `win-v` w nazwie release:
   - **PolskiWhisper-X.Y.Z-win-x64.msi** - Windows na procesorach Intel/AMD (większość)
   - *(lub)* **PolskiWhisper-X.Y.Z-win-arm64.msi** - Windows ARM (np. Surface Pro X)
   - *(lub)* **PolskiWhisper-X.Y.Z-win-x64-portable.zip** - wersja portable, bez instalacji

## Instalacja MSI

1. Kliknij dwukrotnie pobrany plik **.msi**.
2. Jeśli Windows SmartScreen pokaże ostrzeżenie ("Microsoft Defender SmartScreen prevented an unrecognized app from starting") - zobacz sekcję poniżej "[Ostrzeżenie SmartScreen](#ostrzeżenie-smartscreen)".
3. Kliknij "Zainstaluj" w kreatorze (instalacja jest **per-user**, bez UAC, bez admin).
4. Po instalacji aplikacja:
   - Pojawi się w **Menu Start** jako "PolskiWhisper"
   - Ikona pojawi się w **pasku zadań** (system tray, dolny prawy róg)
   - Domyślna ścieżka: `%LOCALAPPDATA%\Programs\PolskiWhisper\`

## Pierwsze uruchomienie - onboarding

Przy pierwszym starcie aplikacja przeprowadzi Cię przez **5 kroków konfiguracji**:

1. **Powitanie** - krótki opis co aplikacja robi i jak działa prywatność
2. **Mikrofon** - wybór urządzenia + test poziomu dźwięku
3. **Model Whisper** - pobranie modelu Turbo (1.5 GB - jednorazowo, ~5 minut na typowym łączu)
4. **Hotkey** - wybór skrótu klawiszowego (domyślnie prawy Ctrl)
5. **Gotowe** - krótkie wskazówki użytkowania

## Ostrzeżenie SmartScreen

Aplikacja używa **self-signed certyfikatu** (świadoma decyzja - filozofia hobby project bez paid Code Signing).
Windows SmartScreen może pokazać ostrzeżenie:

> Microsoft Defender SmartScreen prevented an unrecognized app from starting.
> Running this app might put your PC at risk.

Aby kontynuować:

1. Kliknij link **"More info"** (lub "Więcej informacji").
2. Pojawi się przycisk **"Run anyway"** (lub "Uruchom mimo to").
3. Kliknij - instalacja kontynuuje normalnie.

To ostrzeżenie pojawia się tylko **raz** - po pierwszym uruchomieniu Windows zapamiętuje że aplikacja jest zaufana.

**Dlaczego self-signed?** Code signing certificat ($80-200/rok od Sectigo) eliminuje to ostrzeżenie po reputation building (~kilka tygodni), ale to zbędny koszt dla hobby project.
Jeśli zaufanie jest dla Ciebie ważne - zalecamy zweryfikować checksum pliku (poniżej) lub samodzielnie sbuildować ze źródeł.

## Weryfikacja checksum (opcjonalne)

Każda wersja release ma czeksumy SHA256 dostępne w opisie release na GitHub:

```powershell
# Oblicz SHA256 pobranego pliku.
Get-FileHash .\PolskiWhisper-0.1.0-win-x64.msi -Algorithm SHA256

# Porównaj z opisem release na GitHub.
```

## Wersja portable (alternatywa)

Jeśli wolisz nie instalować nic w systemie - użyj **portable ZIP**:

1. Pobierz `PolskiWhisper-X.Y.Z-win-x64-portable.zip`.
2. Rozpakuj do dowolnego folderu (np. `C:\Apps\PolskiWhisper`).
3. Uruchom `PolskiWhisper.exe`.

W trybie portable settings i model trafiają do `%LOCALAPPDATA%\PolskiWhisper\` (tak samo jak instalka).
Aby usunąć - po prostu skasuj folder z .exe + opcjonalnie `%LOCALAPPDATA%\PolskiWhisper\`.

## Aktualizacja

- **Automatycznie**: Zaznacz "Aktualizuj automatycznie" w Ustawieniach → Ogólne. Aplikacja co 24h sprawdza GitHub i pokazuje toast notification gdy dostępna nowa wersja.
- **Ręcznie**: Ustawienia → Ogólne → "Sprawdź teraz" → "Pobierz i zainstaluj".

Po zainstalowaniu nowej wersji aplikacja automatycznie się zrestartuje.

## Odinstalowanie

### MSI install
1. **Ustawienia Windows** → **Aplikacje** → **Zainstalowane aplikacje**.
2. Znajdź "PolskiWhisper", kliknij **Odinstaluj**.

### Portable
- Skasuj folder z `PolskiWhisper.exe`.
- *(opcjonalnie)* Usuń też dane: `%LOCALAPPDATA%\PolskiWhisper\` (settings, słownik, logi, modele).

## Gdzie aplikacja przechowuje dane?

```
%LOCALAPPDATA%\PolskiWhisper\
├── settings.json          # Konfiguracja użytkownika
├── vocabulary.db          # SQLite ze słownikiem Find & Replace
├── models/                # Pobrane modele Whisper (.bin)
├── temp/                  # Tymczasowe pliki audio (kasowane po wklejeniu)
└── logs/                  # Logi aplikacji (rolling, 7 dni retencji)
```

Brak rejestru Windows poza wpisem "Run" jeśli włączysz autostart, oraz wpisem dla MSI uninstaller.

## Rozwiązywanie problemów

### Hotkey nie działa

- Sprawdź czy aplikacja chodzi w tray (klik prawym na ikonę → "Stan: Gotowy")
- Niektóre aplikacje (Steam, niektóre gry z anti-cheat) blokują global keyboard hooks - PolskiWhisper nie przechwyci hotkey podczas ich używania.
- Spróbuj zmienić hotkey w Ustawieniach → Ogólne (np. F12 zamiast Right Ctrl).

### Tekst się nie wkleja

- Aplikacja nagrywa, transkrybuje, ale wklejenie nie działa? Może to Notatnik z UAC elevated - InputSimulator nie wkleja do okien o wyższym poziomie integralności.
- Spróbuj wkleić ręcznie - tekst jest w schowku.

### Whisper długo ładuje

- Pierwsze ładowanie modelu zajmuje ~10s (Whisper Turbo 1.5 GB do RAM).
- Kolejne uruchomienia są szybsze.
- Jeśli przekracza 30s i widać błąd timeout - możliwe że masz mało wolnego RAM. Spróbuj mniejszego modelu (Small).

### Brak dostępu do mikrofonu

- **Ustawienia Windows** → **Prywatność** → **Mikrofon** → Włącz "Zezwalaj aplikacjom na dostęp do mikrofonu".
- Sprawdź czy konkretne urządzenie nie jest mute w Settings dźwięku.

### Aplikacja crashuje przy starcie

- Sprawdź log: `%LOCALAPPDATA%\PolskiWhisper\logs\polskiwhisper-YYYY-MM-DD.log`.
- Zgłoś bug w [Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues) z attachmentem ostatniego loga.

## Kontakt

Problemy ze instalacją? [kontakt@marcinwerner.com](mailto:kontakt@marcinwerner.com) lub [GitHub Issues](https://github.com/marcinwerner/polskiwhisper.pl/issues).
