#!/usr/bin/env bash
# Regenerate the app icons from assets/app-icon/pdfcraft.svg and the Windows PDF file icon
# from assets/app-icon/pdfcraft-document.svg. Both are master vectors.
#
# Needs: resvg (brew install resvg / cargo install resvg) and python3 (stdlib only, for the .ico).
# On macOS, iconutil also writes the .icns. The outputs are committed, so building and packaging
# never need these tools. After running it, update the sha256 values in ATTRIBUTION.toml, then
# `cargo xtask assets --write`.
#
#   packaging/icons.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/assets/app-icon"
SVG="$DIR/pdfcraft.svg"
ID="ai.storyteller.pdfcraft"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v resvg >/dev/null || { echo "error: resvg not found (brew install resvg)" >&2; exit 1; }

# The master is a full-bleed 512 tile (rx=112): right for Windows and Linux. macOS icons follow
# Apple's grid instead: an 824 px body centred on a transparent 1024 canvas.
MAC="$TMP/macos.svg"
{
  echo '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1024 1024">'
  echo '<image x="100" y="100" width="824" height="824" xlink:href="'"$SVG"'"/>'
  echo '</svg>'
} >"$MAC"

render() {
  local src="$1" size="$2" out="$3"
  resvg -w "$size" -h "$size" "$src" "$out" </dev/null
}

# 1024 px PNG on Apple's grid (also the runtime Dock icon on macOS, see apps/pdfcraft/src/main.rs).
render "$MAC" 1024 "$DIR/pdfcraft-1024.png"

# Linux hicolor theme (full bleed; hicolor/256x256 is also the runtime icon on Windows and Linux).
for s in 16 24 32 48 64 128 256; do
  mkdir -p "$DIR/hicolor/${s}x${s}/apps"
  magick "$DIR/hicolor/512x512/apps/ai.storyteller.pdfcraft.png" -resize "${s}x${s}" "$DIR/hicolor/${s}x${s}/apps/$ID.png"
done
mkdir -p "$DIR/hicolor/scalable/apps"
cp "$SVG" "$DIR/hicolor/scalable/apps/$ID.svg"

# Windows uses the supplied multiresolution ICO files in assets/app-icon directly.

# macOS .icns.
if command -v iconutil >/dev/null; then
  SET="$TMP/pdfcraft.iconset"
  mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    render "$MAC" "$s" "$SET/icon_${s}x${s}.png"
    render "$MAC" $((s * 2)) "$SET/icon_${s}x${s}@2x.png"
  done
  iconutil -c icns -o "$DIR/pdfcraft.icns" "$SET"
else
  echo "warning: iconutil not found (macOS only); pdfcraft.icns not regenerated" >&2
fi
echo "icons written to $DIR"
