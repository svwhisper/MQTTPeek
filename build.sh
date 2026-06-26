#!/bin/bash
# Build MQTTPeek and assemble a runnable .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="MQTTPeek.app"
BIN=".build/${CONFIG}/MQTTPeek"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

echo "==> assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/MQTTPeek"
cp Info.plist "${APP}/Contents/Info.plist"

# Ad-hoc sign so the local network / launch works without Gatekeeper friction.
codesign --force --deep --sign - "${APP}" >/dev/null 2>&1 && echo "==> ad-hoc signed" || echo "==> codesign skipped"

echo "==> done: $(pwd)/${APP}"
echo "    run with:  open '${APP}'   (or)   ./${APP}/Contents/MacOS/MQTTPeek"
