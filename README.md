# MQTT Peek

A tiny native macOS app that subscribes to a single MQTT topic and displays its
latest value in a frameless, always-on-top window — and/or in the menu bar.

Native Swift / AppKit. One dependency ([CocoaMQTT](https://github.com/emqx/CocoaMQTT)).
The built app is ~1.4 MB.

## Build & run

```sh
./build.sh           # release build → MQTTPeek.app
open MQTTPeek.app
```

First launch opens **Preferences** because nothing is configured yet. Enter your
broker host, port, and topic, then **Save & Connect**.

To install it permanently, drag `MQTTPeek.app` into `/Applications`.

## Using it

- **Frameless window** — shows the topic name (caption), the latest value, and a
  status dot (green = connected, yellow = connecting, red = disconnected).
  Drag it anywhere by its body. **Right-click** it for the menu
  (Preferences, Always on Top, Hide Window, Quit).
- **Preferences** (`⌘,` or right-click → Preferences):
  - *Connection*: broker, port, topic, username, password, TLS (+ allow untrusted cert).
  - *Display*: Always on top · Show value in menu bar · Hide window (menu bar only) ·
    Show topic caption · Font size.
- **Always on top** — keeps the window above other windows.
- **Show value in menu bar** — adds a menu-bar item showing the value.
- **Hide window (menu bar only)** — hides the window *and* removes the Dock icon, so
  the app becomes invisible except for the menu-bar item. (This automatically turns on
  the menu-bar item, since that becomes the only way to reach Preferences/Quit.)

## Note on the menu bar + notch

On a notched Mac (e.g. 15" MacBook Air) **with a full menu bar**, macOS places a new
menu-bar item in the overflow zone to the *left* of the notch, where the notch hides
it. The item is still live and working — it's a macOS placement limitation, not a bug
in this app. If the menu-bar item doesn't appear:

- free up menu-bar space (quit/hide a few other menu-bar apps), **or**
- use a menu-bar manager such as [Ice](https://github.com/jordanbaird/Ice) (free) or
  Bartender, **or**
- just use the frameless window (the default), which is unaffected.

## Settings storage

Settings live in `UserDefaults` under `com.svwhisper.mqttpeek`
(`~/Library/Preferences/com.svwhisper.mqttpeek.plist`). Reset with:

```sh
defaults delete com.svwhisper.mqttpeek
```

The MQTT password is stored in `UserDefaults` for simplicity (fine for a LAN broker).
If you ever point this at an internet-facing broker, move the password to the Keychain.
