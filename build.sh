#!/bin/bash
# Build MQTTPeek and assemble a runnable .app bundle.
#
#   ./build.sh                 release build, native arch (fast — for local dev)
#   ./build.sh debug           debug build, native arch
#   UNIVERSAL=1 ./build.sh     release, universal (arm64 + x86_64) — used by CI
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="MQTTPeek.app"

# Build, then ask SwiftPM where it put the product (robust to arch/triple).
if [ "${UNIVERSAL:-0}" = "1" ]; then
    echo "==> swift build -c ${CONFIG} --arch arm64 --arch x86_64"
    swift build -c "${CONFIG}" --arch arm64 --arch x86_64
    BIN_DIR="$(swift build -c "${CONFIG}" --arch arm64 --arch x86_64 --show-bin-path)"
else
    echo "==> swift build -c ${CONFIG}"
    swift build -c "${CONFIG}"
    BIN_DIR="$(swift build -c "${CONFIG}" --show-bin-path)"
fi
BIN="${BIN_DIR}/MQTTPeek"

echo "==> assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/MQTTPeek"
cp Info.plist "${APP}/Contents/Info.plist"

# Ad-hoc sign so launch works without Gatekeeper friction (no Developer ID needed).
codesign --force --deep --sign - "${APP}" >/dev/null 2>&1 && echo "==> ad-hoc signed" || echo "==> codesign skipped"

echo "==> done: $(pwd)/${APP}"
echo "    run with:  open '${APP}'   (or)   ./${APP}/Contents/MacOS/MQTTPeek"
