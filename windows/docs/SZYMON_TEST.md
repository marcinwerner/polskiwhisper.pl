# Test PolskiWhisper na Windows - przewodnik dla testera

> **Cel**: Sprawdź czy aplikacja w ogóle uruchamia się na Windows + napisz co działa, a co nie.
> **Wersja testowa**: v0.1.0 - **placeholder UI** (tylko okno z napisem "PolskiWhisper").
> Pełne UI z 4 zakładkami Settings + dyktowanie głosowe to kolejne wydanie.

## Co masz przetestować

W tej wersji `v0.1.0` testujemy najprostszą rzecz:

a) **Czy aplikacja w ogóle się uruchamia** na Windows
b) **Czy nie wywala się od razu** (crash przy starcie)
c) **Czy widzisz okno** z napisem "PolskiWhisper v0.1.0"
d) **Czy ikona** pojawia się w pasku zadań (system tray, dolny prawy róg)

To wszystko! Pełne dyktowanie po polsku przyjdzie w wersji `v0.2.0`.

## Wymagania

- Windows 10 1809+ lub Windows 11 (do sprawdzenia: Win+R → wpisz `winver`)
- Mikrofon (do późniejszych testów)
- ~4 GB wolnego RAM
- ~500 MB wolnego dysku

## Jak pobrać

### Krok 1: Pobranie ZIP z GitHub

1. Wejdź na **https://github.com/marcinwerner/polskiwhisper.pl/actions**
2. Kliknij na **najnowszy zielony ✓ run** (po lewej, najwyżej)
3. Przewiń stronę na sam dół do sekcji **"Artifacts"**
4. Kliknij **`PolskiWhisper-win-x64`** - zacznie się pobieranie ZIP-a (~150-200 MB)

> **Uwaga**: Aby pobrać artifacts musisz być **zalogowany do GitHub**. Bez konta nie zadziała.
> Jeśli nie masz konta - poproś tatę o link do konkretnego artifacta i prześle Ci.

### Krok 2: Rozpakowanie

1. Po pobraniu znajdź plik `PolskiWhisper-win-x64.zip` w folderze `Pobrane` (Downloads)
2. Kliknij prawym → **"Wyodrębnij wszystko..."** lub **"Extract All..."**
3. Wybierz lokalizację (np. `Pulpit\PolskiWhisper`)
4. Po rozpakowaniu folder powinien zawierać `PolskiWhisper.exe` oraz wiele plików .dll

### Krok 3: Uruchomienie

1. Wejdź do rozpakowanego folderu
2. Dwa razy kliknij **`PolskiWhisper.exe`**

#### Jeśli pojawi się ostrzeżenie "Windows protected your PC" (SmartScreen)

To **normalne** - aplikacja jest podpisana self-signed certyfikatem (świadoma decyzja, brak zakupu Code Signing $80/rok dla hobby project).

Aby kontynuować:
1. Kliknij link **"Więcej informacji"** lub **"More info"**
2. Kliknij przycisk **"Uruchom mimo to"** lub **"Run anyway"**

To ostrzeżenie pojawi się tylko **raz** dla tej wersji aplikacji.

### Krok 4: Co powinno się stać

Powinieneś zobaczyć:
- **Okno aplikacji** z dużym napisem **"PolskiWhisper"** + wersja **"v0.1.0"** + napis "Wstępna wersja Windows - placeholder UI"
- (możliwe) **Ikona w pasku zadań** w prawym dolnym rogu Windows

To wszystko co ma być w v0.1.0. Brak interakcji - tylko sprawdzenie czy startuje.

## Co napisać w raporcie

Wyślij ojcu krótki email lub message z odpowiedziami na:

a) **Czy aplikacja się uruchomiła?** TAK / NIE
b) **Czy pojawiło się okno z napisem "PolskiWhisper"?** TAK / NIE
c) **Jeśli NIE - czy był jakiś komunikat błędu?** Przepisz dokładnie tekst albo zrób screenshot
d) **Czy SmartScreen blokował i jak?** TAK / NIE / nie pamiętam
e) **Wersja Windows**: skopiuj z `winver` (np. "Windows 11 23H2")

## Jeśli aplikacja się wywala lub nic się nie dzieje

To **nie znaczy że zrobiłeś coś źle** - to nasza pierwsza wersja na Windows i może mieć błędy.

Sprawdź log:

1. Naciśnij **Win+R**
2. Wpisz: `%LOCALAPPDATA%\PolskiWhisper\logs`
3. Kliknij OK
4. Powinien otworzyć się folder z plikami `polskiwhisper-YYYY-MM-DD.log`
5. Otwórz najnowszy plik (Notatnik)
6. **Skopiuj ostatnie 50 linii** i wyślij ojcu

Jeśli folder nie istnieje - aplikacja w ogóle się nie uruchomiła. Po prostu napisz "folder nie istnieje" + screenshot ekranu po próbie uruchomienia.

## Dlaczego ta wersja jest taka prosta?

Pełna aplikacja PolskiWhisper na macOS ma:
- Settings z 4 zakładkami (Ogólne, Whisper, Słownik, O programie)
- Pływające okno z waveform podczas nagrywania
- Onboarding wizard (5 kroków first-run)
- System tray icon z menu kontekstowym
- 9 dźwięków systemowych do wyboru
- Słownik Find & Replace z drag-and-drop

Na Windows wszystko to jest **napisane w kodzie** ale tymczasowo wyłączone z kompilacji - chcemy najpierw zweryfikować że minimum działa.

W wersji v0.2.0 (po Twoim feedbacku) odblokujemy pełne UI.

## Kontakt

- Bezpośrednio do ojca: kontakt@marcinwerner.com

Dzięki za pomoc! 🙌
