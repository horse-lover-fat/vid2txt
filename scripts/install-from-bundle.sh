#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=path-setup.sh
source "$DIR/path-setup.sh"

SOURCE="${VID2TXT_SOURCE:-$DIR/vid2txt}"
DEST="$LOCAL_BIN/vid2txt"

if [[ ! -f "$SOURCE" ]]; then
  echo "vid2txt binary not found at: $SOURCE" >&2
  exit 1
fi

ensure_local_bin_dir
install -m 755 "$SOURCE" "$DEST"
ensure_path_in_shell_configs

echo
echo "Installed: $DEST"
