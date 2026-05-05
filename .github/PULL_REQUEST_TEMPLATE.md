## Co zmieniam

Krótki opis zmian.

## Dlaczego

Co rozwiązuje ten PR? Link do issue jeśli istnieje (#123).

## Jak testowałem

- [ ] Build przechodzi (`xcodebuild build`)
- [ ] Unit testy przechodzą (`xcodebuild test`)
- [ ] Manualne testy:
  - [ ] Hotkey toggle działa
  - [ ] Polskie znaki w transkrypcji są poprawne (ą, ę, ś, ć, ź, ż, ó, ł, ń)
  - [ ] Auto-paste działa w Notes / TextEdit
  - [ ] Brak nowych warningów w Console.app
- [ ] Network audit (jeśli dotyczy):
  ```bash
  grep -rn "URLSession\|URLRequest" PolskiWhisper/
  ```
  Wszystkie nowe połączenia są opisane w [PRIVACY.md](docs/PRIVACY.md)

## Checklist

- [ ] Header copyright we wszystkich nowych plikach Swift
- [ ] Zero `print()` - tylko `os.Logger`
- [ ] Zero force unwraps `!` (lub explicit komentarz dlaczego safe)
- [ ] Zero polskich znaków w identifiers (tylko w UI strings i komentarzach)
- [ ] CHANGELOG.md zaktualizowany jeśli zmiana user-visible
- [ ] PRIVACY.md zaktualizowany jeśli dodajesz nowe network calls

## Screeny / nagrania

Jeśli zmiana wpływa na UI - załącz przed/po.
