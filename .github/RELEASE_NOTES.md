Prebuilt, ad-hoc-signed **universal (arm64 + x86_64)** `MQTTPeek.app`.

### Install
1. Download and unzip `MQTTPeek.app.zip`.
2. Move `MQTTPeek.app` to `/Applications`.
3. It's ad-hoc signed (no Developer ID), so clear the download quarantine once:
   ```sh
   xattr -dr com.apple.quarantine /Applications/MQTTPeek.app
   ```
   …or just right-click the app → **Open** the first time.

First launch opens **Preferences** — enter your broker host, port, and topic, then
**Save & Connect**.
