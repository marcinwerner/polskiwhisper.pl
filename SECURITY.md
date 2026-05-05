# Polityka bezpieczeństwa

## Zgłaszanie luk

Jeśli odkryjesz lukę bezpieczeństwa w PolskiWhisper, **NIE otwieraj publicznego Issue**.

Zamiast tego użyj **[GitHub Security Advisories](https://github.com/marcinwerner/polskiwhisper.pl/security/advisories/new)** - prywatny kanał dla zgłoszeń bezpieczeństwa.

W zgłoszeniu uwzględnij:
- Szczegółowy opis luki
- Krok-po-kroku jak odtworzyć
- Wpływ (impact) - co user może stracić
- Sugerowany fix jeśli masz pomysł
- Twoje preferencje co do disclosure (publicznie / prywatnie)

## Co kwalifikuje się jako luka

- **Wyciek danych użytkownika** - jakiekolwiek dane (transkrypcje, audio, słownik) trafiają poza komputer bez zgody
- **Network call do nieudokumentowanego endpointu** - aplikacja łączy się z czymś nie wymienionym w [docs/PRIVACY.md](docs/PRIVACY.md)
- **Code injection** - złośliwy input transkrypcji powoduje wykonanie poleceń
- **Privilege escalation** - aplikacja uzyskuje uprawnienia poza tym co user explicit grantował
- **Crash exploit** - specjalnie skonstruowany input powoduje crash (potencjalnie z exploit potential)

## Co NIE jest luką

- "Nie podpisana cyfrowo aplikacja" - świadoma decyzja, dystrybucja przez DMG bez Apple Developer ID. User omija "unidentified developer" warning manualnie (instrukcja w [docs/INSTALL.md](docs/INSTALL.md))
- "Aplikacja wymaga uprawnienia X" - mikrofon i Accessibility są niezbędne dla podstawowej funkcji (dyktowanie + auto-paste)
- "Pliki audio są zapisywane temp" - tak, w `~/Library/Caches/PolskiWhisper/`, kasowane po success paste. Crash recovery feature

## Czas reakcji

- **Confirmation** odebrania zgłoszenia: 48h
- **Initial assessment**: 7 dni
- **Fix dla critical**: 14 dni
- **Fix dla wysokiej wagi**: 30 dni
- **Public disclosure**: po fixie (lub po 90 dniach jeśli fix niemożliwy)

## Disclosure

Po fixie wszystkie luki są ujawnione publicznie w:
- [CHANGELOG.md](CHANGELOG.md) sekcja "Naprawione bezpieczeństwo"
- [Security Advisories](https://github.com/marcinwerner/polskiwhisper.pl/security/advisories) na GitHub
- Oddzielne CVE jeśli wystarczająco poważne

Reporter dostaje credit (chyba że woli pozostać anonimowo).

## Out of scope

- Lukami w third-party dependencies (WhisperKit, Ollama, GRDB, etc.) zajmują się ich autorzy. Pełna lista w [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md). Zgłaszaj im bezpośrednio.
- Lukami w macOS - Apple Security Bounty Program: https://security.apple.com/bounty/

## Bezpieczeństwo by architecture

PolskiWhisper jest projektowany z myślą o prywatności:
- **Brak telemetrii** - audytowalne przez `grep -rn "URLSession" PolskiWhisper/Sources/`
- **Brak konta** - nie ma czego "włamać"
- **Lokalne przetwarzanie** - audio i transkrypcje nie opuszczają komputera
- **Brak cloud sync** - nawet jeśli Twój komputer zostanie skompromitowany, nic w cloud
- **Open source MIT** - każdy może audytować kod

Zobacz [docs/PRIVACY.md](docs/PRIVACY.md) dla pełnego opisu architektury bezpieczeństwa.
