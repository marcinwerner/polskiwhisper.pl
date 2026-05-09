# Architektura - PolskiWhisper Windows

> **Wersja**: 0.1.0-preview (2026-05-09)
> **Stack**: WinUI 3 + C# 12 + .NET 8 LTS (8.0.420) + Whisper.net 1.5.0
> **Status**: pre-release placeholder UI - 12 komponentów wyłączonych w csproj (patrz "Wyłączone komponenty" niżej)

Dokument opisuje strukturę kodu i kluczowe decyzje architektoniczne. Mapping 1:1 z wersją macOS - dla developera z jednym backgroundem łatwo zrozumieć drugą stronę.

---

## Wysokopoziomowa struktura

```
windows/
├── PolskiWhisperWin.sln                    # Visual Studio solution
├── src/
│   ├── PolskiWhisperWin/                   # Main app (WinUI 3 + .NET 8)
│   │   ├── App.xaml(.cs)                   # Application root
│   │   ├── Program.cs                      # Custom Main() - WinUI 3 entry
│   │   ├── app.manifest                    # DPI awareness, OS version
│   │   ├── Features/
│   │   │   ├── Dictation/                  # NAudioRecorder, ClipboardPasteService
│   │   │   ├── Updates/                    # NotificationDispatcher, DuplicateAppFinder, SelfUpdateInstaller
│   │   │   └── UI/                         # MainWindow, Floating, Pages, TrayIcon, Sound
│   │   ├── Onboarding/                     # OnboardingWindow + 5 step pages
│   │   ├── Hotkey/                         # HotkeyMonitor (SharpHook)
│   │   ├── Supporting/                     # AppCoordinator, Serilog, CrashHandler, LaunchAtLogin
│   │   └── Assets/                         # Ikony, dźwięki, brand
│   ├── PolskiWhisperWin.Core/              # Pure business logic (testowalny)
│   │   ├── Models/                         # Records: AppPhase, FindReplaceRule, UpdateInfo, AppSettings
│   │   ├── Services/                       # Interfaces + implementations
│   │   └── Utilities/                      # SemVer, AppPaths
│   └── PolskiWhisperWin.Tests/             # xUnit tests
│       └── Services/                       # Vocabulary, Hallucination, Settings, Vocab DB tests
├── installer/
│   └── PolskiWhisperWin.wxs                # WiX 4 MSI definition
├── scripts/
│   ├── build.ps1                           # Build + test + publish
│   ├── build-installer.ps1                 # WiX MSI build
│   └── release.ps1                         # Tag + GitHub Release
└── docs/
    ├── INSTALL.md                          # User-facing install guide
    ├── PRIVACY.md                          # Privacy policy
    └── ARCHITECTURE.md                     # Ten plik
```

### Dlaczego rozdział `Core` vs `Main app`?

**`PolskiWhisperWin.Core`** = czysty .NET 8, **bez UI dependencies**:
- Łatwo testować (`xUnit`).
- Cross-platform-ready (jeśli kiedyś chcemy Linux lub Avalonia jednolity Mac/Win, większość kodu już jest gotowa).
- Wszystkie typy biznesowe: `DictationEngine`, `WhisperService`, `VocabularyProcessor`, `HallucinationFilter`, `UpdateChecker`.

**`PolskiWhisperWin`** = `net8.0-windows10.0.19041.0`, używa Windows-specific API:
- WinUI 3 dla UI.
- NAudio dla audio capture.
- SharpHook dla global keyboard.
- TextCopy + InputSimulator dla auto-paste.
- Microsoft.Toolkit.Uwp.Notifications dla Toast.
- H.NotifyIcon dla system tray.

---

## Kluczowe komponenty (deep dive)

### DictationEngine (Core)

**Centralny orchestrator** flow audio → Whisper → vocabulary → paste. State machine z fazami:

```
Idle → Recording → Processing → Pasting → Completed → Idle
                ↓
              Error → Idle (po 2s)
```

**Kontrakt**:
- `StartDictationAsync()` - przejście Idle → Recording. Idempotent.
- `StopDictationAsync()` - Recording → Processing → Pasting → Completed → Idle. Pełen pipeline.
- `CancelDictationAsync()` - Recording → Idle. Skasuje temp WAV bez transcribe.

**Auto-spacing logic** (mapping z macOS v0.1.2):
- Po wklejeniu zapamiętujemy `_lastPasteAt` + `_lastPasteEndedWithTerminator` (czy `.!?` na końcu).
- W kolejnym wklejeniu, jeśli `_lastPasteAt < 60s` i poprzednie kończyło się terminator i kolejne nie zaczyna się od whitespace → dopisz wiodącą spację.

**Silence detection** (mapping z macOS v0.1.1):
- Jeśli `AudioRecordingResult.MaxRms < 0.01` → `SilentRecordingException` → skip transcribe, pokaż "Idle" bez błędu.
- Eliminuje halucynacje "Dziękuję za oglądanie" przy ciszy.

### WhisperService - timeout pattern

**Krytyczny punkt: timeout** (nauka z macOS ADR-028).

**Stary macOS pattern (broken)**: `withThrowingTaskGroup` - czekał na cancelled child task aż się skończy. Whisper.cpp nie reagował na cancel → app hang mimo "timeout fired" w log.

**Nowy pattern w C# (działa)**:

```csharp
using var timeoutCts = new CancellationTokenSource(timeout);
using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutCts.Token);

var transcribeTask = TranscribeInternalAsync(wavFilePath, linkedCts.Token);
var timeoutTask = Task.Delay(timeout, cancellationToken);

var winner = await Task.WhenAny(transcribeTask, timeoutTask);

if (winner == timeoutTask && !transcribeTask.IsCompleted)
{
    // First-wins: rzucamy timeout; transcribeTask continues w tle (detached).
    _ = transcribeTask.ContinueWith(t => { /* log if faulted */ });
    throw new TranscriptionTimeoutException((int)timeout.TotalSeconds);
}
```

Whisper.net **może** ignorować cancellation token (whisper.cpp implementacja). Akceptujemy że background task continues - file handle disposed osobno, OS sprzątnie pamięć.

### HotkeyMonitor (SharpHook)

**Tap vs Hold detection**:
- `KeyPress` event ustawia `_hotkeyPressedAt`.
- Po 250ms timer sprawdza czy klawisz wciąż wciśnięty - jeśli tak: emituj `HotkeyHoldStart`.
- `KeyRelease` event:
  - Jeśli `_hotkeyHoldEmitted == true`: emituj `HotkeyHoldEnd`.
  - Inaczej (krótki tap): emituj `HotkeyTapped`.

Mapping VK code → SharpHook KeyCode w `MapVkToSharpHookKeyCode()` - wystarczające dla popularnych klawiszy (lewy/prawy ctrl/alt/shift, F-keys, Caps Lock).

### Auto-update flow

**Mapping z macOS v0.1.5 ADR-026**.

1. `IUpdateChecker.CheckForUpdateAsync()` → GET `/releases?per_page=20` → filtruj `tag_name.startsWith("win-")` → znajdź najnowszy → porównaj z `currentVersion` przez `SemanticVersion`.
2. Jeśli newer: `NotificationDispatcher.ShowUpdateAvailable()` → toast notification.
3. User klik "Pobierz i zainstaluj" w Settings → `IUpdateChecker.DownloadInstallerAsync()` → MSI w `%TEMP%`.
4. `SelfUpdateInstaller.InstallAndRestart(msiPath)`:
   - Generuje PowerShell skrypt w `%TEMP%`.
   - `Start-Process powershell.exe -Args "-File <script>"` - background.
   - `Environment.Exit(0)` - kończy aktualną aplikację.
5. PowerShell skrypt:
   - `Wait-Process` na PID poprzedniej aplikacji (max 15s).
   - `Start-Process msiexec /i installer.msi /quiet /norestart -Wait`.
   - `Start-Process PolskiWhisper.exe`.
   - Sprzątanie MSI + sam się usuwa.

**Brak dependencies na 3rd-party** (Velopack, Squirrel) - same .NET + PowerShell. Pełna kontrola, mała atrak surface.

---

## Persystencja danych

### Settings - JSON

`%LOCALAPPDATA%\PolskiWhisper\settings.json` - serializowany `AppSettings`:

```json
{
  "selectedWhisperModelId": "ggml-large-v3-turbo",
  "hotkeyVirtualKeyCode": 163,
  "hotkeyMode": "Toggle",
  "startSound": "Pop",
  "finishSound": "Tink",
  "maxRecordingSeconds": 300,
  "launchAtLogin": false,
  "automaticUpdatesEnabled": true,
  "onboardingCompleted": true,
  "useGpuAcceleration": true,
  "lastUpdateCheck": "2026-05-08T12:34:56Z"
}
```

**Atomic write**: `JsonSettingsStore.SaveAsync` zapisuje do `settings.json.tmp`, potem `File.Replace`. Crash-safe.

### Vocabulary - SQLite

`%LOCALAPPDATA%\PolskiWhisper\vocabulary.db`:

```sql
CREATE TABLE find_replace_rule (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    find_text     TEXT NOT NULL,
    replace_with  TEXT NOT NULL,
    is_regex      INTEGER NOT NULL DEFAULT 0,
    case_sensitive INTEGER NOT NULL DEFAULT 0,
    order_index   INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL
);
CREATE INDEX idx_find_replace_rule_order ON find_replace_rule(order_index);

CREATE TABLE schema_version (version INTEGER PRIMARY KEY);
```

**Migrations**: `schema_version` table - obecnie tylko v1. Dodanie kolumn w przyszłości = nowa migracja.

### Logs - Serilog rolling

`%LOCALAPPDATA%\PolskiWhisper\logs\polskiwhisper-YYYY-MM-DD.log`:
- Daily rolling.
- 7 dni retencji.
- 10 MB max size per file.
- Format: `[YYYY-MM-DD HH:mm:ss.fff LEVEL] [Thread] {SourceContext}: Message`.

**Privacy**: nigdy nie logujemy treści transkrypcji, tylko metadane (długość audio, status, errors).

---

## Dependency Injection

`AppCoordinator.ConfigureServices(services)` rejestruje:

| Interfejs | Implementacja | Lifecycle |
|---|---|---|
| `IAppPaths` | `AppPaths` | Singleton |
| `HttpClient` | `new HttpClient { Timeout = 20min }` | Singleton |
| `ISettingsStore` | `JsonSettingsStore` | Singleton |
| `IVocabularyStore` | `SqliteVocabularyStore` | Singleton |
| `VocabularyProcessor` | (sam siebie) | Singleton |
| `WhisperHallucinationFilter` | (sam siebie) | Singleton |
| `IWhisperService` | `WhisperService` | Singleton |
| `IUpdateChecker` | `UpdateChecker` | Singleton |
| `IAudioRecorder` | `NAudioRecorder` | Singleton |
| `IPasteService` | `ClipboardPasteService` | Singleton |
| `HotkeyMonitor` | (sam siebie) | Singleton |
| `TrayIconController` | (sam siebie) | Singleton |
| `NotificationDispatcher` | (sam siebie) | Singleton |
| `DuplicateAppFinder` | (sam siebie) | Singleton |
| `SoundService` | (sam siebie) | Singleton |
| `LaunchAtLoginManager` | (sam siebie) | Singleton |
| `SelfUpdateInstaller` | (sam siebie) | Singleton |
| `DictationEngine` | (sam siebie) | Singleton |

**Wszystko Singleton** - aplikacja jest single-window (Settings) + single-tray. Nie ma scope-ów request-like.

`App.Coordinator` to globalny dostęp - używany przez code-behind XAML pages dla DI lookup. Mniej elegancki niż MVVM + DI w View, ale dla hobby project to zaakceptowane (każdy w PolskiWhisper team rozumie patrn).

---

## Wątkowanie

### UI thread

WinUI 3 ma jeden UI thread (DispatcherQueue) - wszystkie aktualizacje XAML muszą być przez `_dispatcherQueue.TryEnqueue(() => ...)`.

**Mam już zorganizowane**:
- `DictationEngine.PhaseChanged` event firen jest **z dowolnego thread** - listener-y używają DispatcherQueue.
- `IAudioRecorder.RmsLevelChanged` firen z NAudio buffer thread - `WaveformView` używa DispatcherQueue.
- `IWhisperService.LoadModelAsync` rzuca progress callbacks - `WhisperSettingsPage` używa DispatcherQueue.

### Background work

- **Whisper transcribe** - `Task.Run` w `DictationEngine.ProcessRecordingAsync`.
- **Update check** - `Task.Run` w `App.OnLaunched`.
- **Model load** - `Task.Run` z progress callback do UI thread.

---

## Testowalność

`PolskiWhisperWin.Tests` zawiera testy dla:

| Klasa | Test file | Co testuje |
|---|---|---|
| `SemanticVersion` | `SemanticVersionTests.cs` | Parse, compare, edge cases |
| `VocabularyProcessor` | `VocabularyProcessorTests.cs` | Find/replace, regex, case-sensitivity, multi-rule order, invalid regex skip |
| `WhisperHallucinationFilter` | `WhisperHallucinationFilterTests.cs` | Known phrases, diacritic-fold, normalization |
| `JsonSettingsStore` | `JsonSettingsStoreTests.cs` | Default load, round-trip, concurrent reads |
| `SqliteVocabularyStore` | `SqliteVocabularyStoreTests.cs` | CRUD, ordering, reorder |
| `DictationEngine.ApplyAutoSpacing` | `DictationEngineAutoSpacingTests.cs` | Auto-spacing logic edge cases |

**Mockowane**: `IAudioRecorder`, `IWhisperService`, `IPasteService`, `IVocabularyStore` przez Moq.

**Test coverage focus**: pure logic (nie UI). UI jest manual-testable przez running aplikację.

---

## Build & deployment

### Local development

```powershell
.\scripts\build.ps1                         # Debug build
.\scripts\build.ps1 -RunTests               # Build + tests
.\scripts\build.ps1 -Configuration Release -Publish -Runtime win-x64
```

### CI (GitHub Actions)

`.github/workflows/windows-ci.yml`:
- **PR**: build + tests on `windows-latest`.
- **Push to main**: build + publish + MSI upload as artifact.
- **Tag `win-vX.Y.Z`**: GitHub Release z MSI + ZIP.

### Release

```powershell
# Po update CHANGELOG.md + version bump w .csproj.
.\scripts\build.ps1 -Configuration Release -Publish -RunTests
.\scripts\build-installer.ps1 -Version 0.1.0
.\scripts\release.ps1 -Version 0.1.0
```

---

## Open questions / future work

| # | Pytanie | Status |
|---|---|---|
| 1 | Multi-monitor: gdzie pokazać floating window? | Aktualne: główny monitor. Settings w przyszłości. |
| 2 | DPI scaling | WinUI 3 native auto - testy na 100/125/150/200%. |
| 3 | Light/Dark mode | WinUI 3 ThemeListener - auto follow system. Test po MSI. |
| 4 | Język UI | Tylko polski v0.1.0. Resource strings ready dla i18n po v1.0. |
| 5 | Beta channel | Settings → Ogólne → "Pokaż prerelease" - po v1.0. |
| 6 | Avalonia migration | Kiedyś jeśli chcemy single codebase Mac/Win. Core już cross-platform. |

---

## Cross-references

- macOS architektura: [../../docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) (jeśli istnieje, lub `.internal/ARCHITECTURE.md`)
- ADR-y macOS: `.internal/DECISIONS.md`
- macOS HANDOFF: `.internal/HANDOFF-*.md`

---

## Wyłączone komponenty (v0.1.0-preview)

XamlCompiler na CI runner (windows-latest) nie raportuje konkretnych błędów dla complex XAML pages - tylko `MSB3073: XamlCompiler.exe exited with code 1` bez stderr. Z bezpieczeństwa CI tymczasowo wyłączono w `windows/src/PolskiWhisperWin/PolskiWhisperWin.csproj`:

```xml
<!-- v0.1.0: tymczasowo wyłączamy complex XAML pages aż XamlCompiler issue zostanie zbadany na Windows machine. -->
<ItemGroup>
  <Page Remove="Features\UI\Pages\GeneralSettingsPage.xaml" />
  <Page Remove="Features\UI\Pages\WhisperSettingsPage.xaml" />
  <Page Remove="Features\UI\Pages\VocabularySettingsPage.xaml" />
  <Page Remove="Features\UI\Pages\AboutPage.xaml" />
  <Page Remove="Features\UI\Floating\FloatingDictationWindow.xaml" />
  <Page Remove="Features\UI\Floating\WaveformView.xaml" />
  <Page Remove="Onboarding\OnboardingWindow.xaml" />
  <Page Remove="Onboarding\Steps\WelcomeStep.xaml" />
  <Page Remove="Onboarding\Steps\MicrophoneStep.xaml" />
  <Page Remove="Onboarding\Steps\ModelStep.xaml" />
  <Page Remove="Onboarding\Steps\HotkeyStep.xaml" />
  <Page Remove="Onboarding\Steps\FinishStep.xaml" />

  <Compile Remove="Features\UI\Pages\**\*.cs" />
  <Compile Remove="Features\UI\Floating\**\*.cs" />
  <Compile Remove="Onboarding\**\*.cs" />
</ItemGroup>

<ItemGroup>
  <Compile Remove="Features\UI\SoundService.cs" />
  <Compile Remove="Features\UI\TrayIconController.cs" />
  <Compile Remove="Features\Updates\NotificationDispatcher.cs" />
</ItemGroup>
```

### Co działa w v0.1.0-preview

- **App.xaml + minimal MainWindow** = okno z napisem "PolskiWhisper v0.1.0"
- **Core library** (Models, Services, Utilities) - skompilowany + tested
- **Whisper.net wrapper, NAudio recorder, ClipboardPasteService, HotkeyMonitor** - skompilowane (niesprawdzone runtime bez modelu/mikrofonu)
- **AppCoordinator z DI** + Serilog logger + CrashHandler
- **DuplicateAppFinder, LaunchAtLoginManager, SelfUpdateInstaller** - skompilowane
- **ClipboardPasteService** używa **InputSimulatorPlus** 1.0.7 (zmiana z H.InputSimulator który nie miał WindowsInput.Native namespace)

### Plan reaktywacji (target v0.2.0)

1. **Otwórz solution w Visual Studio 2022 lokalnie** na Windows machine
2. **Usuń jeden `<Page Remove>` w csproj** (zacząć od najprostszego: `WaveformView.xaml`)
3. **Spróbuj build** w VS - lokalna instalacja XamlCompiler ma full stderr/stdout, pokaże konkretny błąd w XAML
4. **Fix błąd** (najprawdopodobniej drobne API differences: `xmlns:ui` w root, brakujące using, `x:DataType` vs `DataContext`, brakujące converter dla `bool→Visibility`, etc.)
5. **Push** do CI - sprawdź czy CI też przechodzi
6. **Powtórz** dla każdego z 12 komponentów

### Kolejność reaktywacji (sugerowana, od najprostszego do najbardziej skomplikowanego)

1. `WaveformView.xaml` - tylko UserControl z Canvas, najprostsze
2. `FloatingDictationWindow.xaml` - Window z Border + Grid
3. `Steps/*.xaml` - 5 prostych Page-ów onboarding (równolegle)
4. `OnboardingWindow.xaml` - Window z Frame + buttons
5. `AboutPage.xaml` - Page z hyperlinks (najprostszy z Settings tabs)
6. `WhisperSettingsPage.xaml` - Page z ListView + DataTemplate
7. `VocabularySettingsPage.xaml` - Page z drag-drop ListView (najtrudniejszy)
8. `GeneralSettingsPage.xaml` - Page z toggles + ComboBoxes (uproszczona)

### Reaktywacja code-only komponentów

`SoundService.cs`, `TrayIconController.cs`, `NotificationDispatcher.cs` zależą od plików XAML pośrednio (TrayIcon → MainWindow → Settings, Notification → updates flow). Aktywować razem z odpowiednimi UI komponentami.

### Po reaktywacji

- Update `windows/CHANGELOG.md` - zmiana z `0.1.0-preview` (placeholder) na `0.2.0` (full UI)
- Update `windows/README.md` - usunąć "Status: pre-release placeholder UI" + tabelę "co tymczasowo wyłączone"
- Update `windows/docs/ARCHITECTURE.md` - usunąć całą sekcję "Wyłączone komponenty (v0.1.0-preview)"
- Tag `win-v0.2.0` (full release, nie pre-release)
