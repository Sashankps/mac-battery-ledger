# mac-battery-ledger

mac-battery-ledger is a native macOS menu bar app for MacBooks. It replaces the default battery percentage menu item with a compact battery icon and percent, then opens a clean SwiftUI panel with charge history, discharge history, cycle count, health, capacity, and live battery status.

## Build

```sh
./Scripts/build-app.sh
```

The app bundle is created at:

```sh
.build/mac-battery-ledger.app
```

## Run during development

```sh
swift run mac-battery-ledger
```

## History

The app stores observed charge and discharge sessions in:

```text
~/Library/Application Support/mac-battery-ledger/history.json
```

A charge session starts while power is connected. A discharge session starts when power is removed and ends when the next charge begins.
