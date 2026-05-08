# Assets - PolskiWhisperWin

Folder zawiera zasoby aplikacji wymagane przed buildem:

## Wymagane pliki przed kompilacją

### Ikony (`*.ico`)

- **AppIcon.ico** - ikona aplikacji (używana jako exe icon i window icon)
  - Format: ICO multi-resolution
  - Sugerowane: 16x16, 32x32, 48x48, 256x256 px
  - Bazowy design: kropka mikrofonu w kolorze `#FF6B4A` (PolskiWhisper brand)

- **TrayIcon.ico** - ikona w system tray
  - Format: ICO multi-resolution
  - Sugerowane: 16x16, 32x32 px
  - Wersje: light + dark mode (Windows automatycznie wybierze)

### Dźwięki (`Sounds/*.wav`)

Bundled .wav pliki dla 9 opcji `SoundChoice`:

- `pop.wav` - krótki delikatny pop
- `tink.wav` - metaliczny brzęk
- `glass.wav` - rozbicie szkła
- `ping.wav` - sonar
- `bottle.wav` - postukanie w butelkę
- `purr.wav` - mruczenie kota
- `hero.wav` - bohaterski akord
- `submarine.wav` - sonar łodzi podwodnej
- `blow.wav` - dmuchnięcie

Format: PCM 16-bit, mono lub stereo, 44.1 kHz, długość maksymalnie 1 sekunda.

## Generowanie placeholder w dev

Dla local dev (jeśli pliki .ico nie są jeszcze przygotowane):

```powershell
# Wygeneruj placeholder .ico z systemowej ikony aplikacji.
$ico = [System.Drawing.SystemIcons]::Application
$stream = New-Object System.IO.FileStream(".\AppIcon.ico", "Create")
$ico.Save($stream)
$stream.Close()

# Skopiuj jako TrayIcon.ico.
Copy-Item ".\AppIcon.ico" ".\TrayIcon.ico"
```

Do dźwięków na początek można skopiować systemowe Windows .wav z `%WINDIR%\Media\` i zmienić nazwy.

## Production assets

Finalne ikony i dźwięki przygotowywane są przez Marcina (lub designer'a):
- Brand source: macOS app icon - port 1:1 z kolorem akcent.
- Hosted: w mw-toolkit `polskiwhisper-brand/` jeśli będzie dedykowany shared folder.
