#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CARGO_TARGET_DIR="$ROOT/target"

PLATFORM="${1:-$(case "$(uname -s)" in Darwin) echo macos ;; Linux) echo linux ;; esac)}"
ARCH="${2:-$(uname -m | sed 's/arm64/aarch64/; s/amd64/x86_64/')}"
FEATURES="${VID2TXT_FEATURES:-}"

case "$PLATFORM" in
  macos | linux) ;;
  *)
    echo "Unsupported platform: $PLATFORM (expected macos or linux)" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  aarch64 | x86_64) ;;
  *)
    echo "Unsupported arch: $ARCH (expected aarch64 or x86_64)" >&2
    exit 1
    ;;
esac

DIST="$ROOT/dist"
ARCHIVE="$DIST/vid2txt-${PLATFORM}-${ARCH}.tar.gz"

echo "Building release binary..."
if [[ -n "$FEATURES" ]]; then
  cargo build --release --features "$FEATURES"
else
  cargo build --release
fi

mkdir -p "$DIST"
tar czf "$ARCHIVE" -C "$CARGO_TARGET_DIR/release" vid2txt

echo "Created: $ARCHIVE"
ls -lh "$ARCHIVE"
