#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT_DIR/.build/AppIcon.iconset"
OUTPUT="${1:-$ROOT_DIR/.build/AppIcon.icns}"
mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"

# Apple's conventional 1x and 2x representations for a bundled macOS icon.
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$ROOT_DIR/Assets/AppIcon.png" \
    --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE_SIZE=$((SIZE * 2))
  sips -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$ROOT_DIR/Assets/AppIcon.png" \
    --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil --convert icns --output "$OUTPUT" "$ICONSET"
