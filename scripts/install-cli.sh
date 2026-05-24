#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# shellcheck source=path-setup.sh
source "$SCRIPT_DIR/path-setup.sh"

BINARY="${VID2TXT_SOURCE:-$ROOT/target/release/vid2txt}"
DEST="${1:-$LOCAL_BIN/vid2txt}"
FEATURES="${VID2TXT_FEATURES:-}"

if [[ ! -x "$BINARY" ]]; then
  echo "Building release binary..."
  if [[ -n "$FEATURES" ]]; then
    cargo build --release --features "$FEATURES"
  else
    cargo build --release
  fi
fi

install_binary() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  install -m 755 "$src" "$dst"
}

if [[ "$DEST" == /usr/local/bin/* || "$DEST" == /usr/bin/* ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    install_binary "$BINARY" "$DEST"
  else
    sudo install -m 755 "$BINARY" "$DEST"
  fi
  echo "Installed: $DEST"
  echo "Run: vid2txt --help"
elif needs_path_setup "$DEST"; then
  ensure_local_bin_dir
  install_binary "$BINARY" "$DEST"
  ensure_path_in_shell_configs
  echo "Installed: $DEST"
else
  install_binary "$BINARY" "$DEST"
  echo "Installed: $DEST"
  echo "Run: vid2txt --help"
fi
