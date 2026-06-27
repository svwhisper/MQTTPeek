# MQTT Peek — session notes

Authoritative living doc for this project. Keep current alongside code changes.

## What it is

A small native macOS menu-bar / floating-window app that subscribes to **one** MQTT
topic and displays its latest payload. Built to be "as minimally visible as possible":
a frameless, draggable, always-on-top window, with an option to disappear entirely into
the menu bar.

Created 2026-06-26.

## Stack & decisions

- **Native Swift / AppKit**, built with Swift Package Manager, wrapped into a `.app`
  bundle by `build.sh`. No Xcode project to maintain. Chosen over Electron (200 MB,
  Node v16 here) and over Python for footprint + native menu-bar/frameless support.
- **MQTT: CocoaMQTT 2.2.6** (pinned). Subscribe-only client (`MQTTManager`). Pulls in
  Starscream 4.0.8 + MqttCocoaAsyncSocket 1.0.8 via SPM (`Package.resolved` committed).
  Hand-rolling MQTT was considered; CocoaMQTT chosen for robustness (auto-reconnect,
  TLS, keepalive handled).
- **Toolchain present:** Swift 6.3.2, full Xcode at `/Applications/Xcode.app`.
- Bundle id `com.svwhisper.mqttpeek`. Settings in `UserDefaults`. Ad-hoc codesigned.
- Built app ≈ 1.4 MB.

## Files

```
Package.swift                  swift-tools 5.9, macOS 12+, dep CocoaMQTT 2.2.6
Info.plist                     bundle metadata (no LSUIElement — policy set at runtime)
build.sh                       swift build -c release → MQTTPeek.app (+ ad-hoc sign)
Sources/MQTTPeek/
  main.swift                   NSApplication entry point
  Preferences.swift            typed UserDefaults wrapper + .prefsChanged notification
  MQTTManager.swift            CocoaMQTT subscribe-only; onValue / onState callbacks;
                               owns reconnection via a watchdog timer
  ValueWindow.swift            frameless ValueWindow + ValueWindowController (layout,
                               drag, status dot, context menu, origin persistence)
  PreferencesWindow.swift      programmatic settings form (connection + display)
  AppDelegate.swift            wiring: applies prefs, owns status item + menus, MQTT
```

## Behaviour model

- **Activation policy** is set at runtime, not via `LSUIElement`:
  - `hideWindow == true`  → `.accessory` (no Dock icon, no app menu) — "invisible" mode.
  - `hideWindow == false` → `.regular` (Dock icon + app menu with Edit menu so the
    Preferences text fields get cut/copy/paste/select-all).
- **Window**: borderless `NSWindow`, `level = .floating` when Always-on-top,
  `isMovableByWindowBackground`, NSVisualEffectView (`.hudWindow`) rounded backdrop,
  auto-sizes to the value text from a stable top-left corner. Position persisted to
  `winX/winY`. Right-click → shared action menu.
- **Menu bar item** (`showInMenuBar || hideWindow`): `NSStatusItem` variable length,
  SF Symbol `antenna.radiowaves.left.and.right` + value text, menu mirrors the window's.
- **Opening Preferences** temporarily forces `.regular` so the menu bar / Edit menu is
  available even in accessory mode; reverts on close. Save writes prefs, posts
  `.prefsChanged` → `applyAll()` + `mqtt.reconnect()`.
- **Connection state** → status dot colour (green/yellow/red) + menu header text.
- **Reconnection** is owned by `MQTTManager`'s watchdog, not CocoaMQTT's `autoReconnect`
  (disabled, to avoid two mechanisms fighting). A repeating `Timer` (every
  `reconnectInterval` = 5 s, added in `.common` runloop mode, tolerance 1 s) calls
  `connectNow()` whenever `wantConnection && state != .connected && Prefs.isConfigured`.
  `connectNow()` tears down any old client (delegate nilled first → late callbacks
  ignored) and builds a fresh one. This covers a normal drop, a broker that's down at
  launch, and a connect stuck in "connecting". Re-subscribe happens in `didConnectAck`
  on every (re)connect, so it survives reconnects regardless of `cleanSession`. Silent
  drops (no TCP FIN) are detected by the 60 s keepalive, then retried within 5 s.
  All state mutations are funnelled through `update()` on the main thread.

## Verified working (2026-06-26)

Tested end-to-end against a throwaway local `mosquitto` on `127.0.0.1:18830` with a
retained message:

- ✅ Connects via CocoaMQTT (broker log shows client `MQTTPeek-<suffix>`), receives the
  retained value, displays it live (AX title confirmed updating, e.g. `42.0` → `23.8 °C`).
- ✅ Frameless translucent always-on-top window renders topic caption + value + green dot.
- ✅ Right-click context menu (Preferences / Always on Top ✓ / Hide Window / Quit) works,
  header shows `topic — connected`.
- ✅ "Hide window (menu bar only)" → window gone, Dock icon gone, app becomes a faceless
  accessory (the app itself is invisible). The MQTT client keeps running.

## Known limitation — notch + full menu bar

The menu-bar **value display** is correctly implemented (the `NSStatusItem` is created,
`isVisible=true`, live title, working menu — confirmed via the accessibility API:
`menu bar item 1 of menu bar 2 of MQTTPeek`, `title=42.0`). **But** on this 15" MacBook
Air (1470×956, notch ≈ x655–815) the menu bar is full to the right of the notch, so
macOS overflows the new item to the *left* of the notch (≈ x635) where the notch hides
it. This is the standard notched-Mac overflow behaviour (what Ice/Bartender solve), not
an app bug. Workarounds documented in README: free menu-bar space, use a menu-bar
manager, or use the window mode (default). Nothing the app can do forces placement past
a full bar + notch.

## CI / Releases

- Repo: `github.com/svwhisper/MQTTPeek` (private).
- `.github/workflows/release.yml` on `macos-15`: triggers on `v*` tags (or manual
  `workflow_dispatch`). Steps: build `UNIVERSAL=1 ./build.sh` → `lipo -info` check →
  `ditto` zip → upload workflow artifact → on tags, `gh release create` with
  `.github/RELEASE_NOTES.md` (uses built-in `GITHUB_TOKEN`, `permissions: contents: write`).
- `build.sh` is the single build path: locates the product via `swift build
  --show-bin-path`; `UNIVERSAL=1` adds `--arch arm64 --arch x86_64` (fat binary).
- Released app is **ad-hoc signed** (`Signature=adhoc`, no Team ID) → downloaders must
  clear quarantine: `xattr -dr com.apple.quarantine /Applications/MQTTPeek.app`.
- v1.0.0 verified: asset `MQTTPeek.app.zip` (~816 KB), binary `x86_64 arm64`, run 1m09s.
- Harmless warning: checkout@v4 / upload-artifact@v4 noted as Node 20 (run on Node 24);
  v4 is current major — nothing to change yet.

## Possible future work

- Move MQTT password to Keychain (currently UserDefaults — fine for LAN).
- Optional value formatting (units suffix, number rounding, JSON-path extraction).
- Multiple topics / small list.
- Proper app icon (`.icns`) — currently none.
