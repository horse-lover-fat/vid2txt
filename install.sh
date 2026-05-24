#!/usr/bin/env bash
set -euo pipefail

REPO="${VID2TXT_REPO:-horse-lover-fat/vid2txt}"
BRANCH="${VID2TXT_INSTALLER_BRANCH:-master}"
INSTALL_DIR="${VID2TXT_INSTALL:-$HOME/.local/bin}"
BINARY="$INSTALL_DIR/vid2txt"
WORKDIR=""

cleanup() {
  if [[ -n "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
}

main() {
  require_cmd curl
  require_cmd tar
  require_cmd uname
  require_cmd install
  require_cmd mktemp

  local platform arch asset url
  platform="$(detect_platform)"
  arch="$(detect_arch)"
  asset="vid2txt-${platform}-${arch}.tar.gz"
  url="${VID2TXT_DOWNLOAD_URL:-https://github.com/$REPO/releases/latest/download/$asset}"

  WORKDIR="$(mktemp -d)"
  trap cleanup EXIT

  load_path_setup "$WORKDIR"

  echo "Downloading $asset..."
  if ! curl -fsSL "$url" -o "$WORKDIR/$asset"; then
    echo "Failed to download release asset: $url" >&2
    echo "A GitHub release may not exist yet. Try building from source instead:" >&2
    echo "  cargo install --git https://github.com/$REPO" >&2
    exit 1
  fi

  tar xzf "$WORKDIR/$asset" -C "$WORKDIR"
  if [[ ! -f "$WORKDIR/vid2txt" ]]; then
    echo "Release archive did not contain a vid2txt binary." >&2
    exit 1
  fi

  ensure_local_bin_dir
  install -m 755 "$WORKDIR/vid2txt" "$BINARY"
  ensure_path_in_shell_configs

  echo
  echo "Installed: $BINARY"
  echo "FFmpeg must be on your PATH (brew install ffmpeg / apt install ffmpeg)."
  echo "Open a new terminal and run: vid2txt --help"
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    *)
      echo "Unsupported operating system: $(uname -s)" >&2
      echo "Build from source instead:" >&2
      echo "  cargo install --git https://github.com/$REPO" >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    arm64 | aarch64) echo "aarch64" ;;
    x86_64 | amd64) echo "x86_64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

load_path_setup() {
  local tmpdir="$1"
  local script_dir path_setup_url

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  if [[ -f "$script_dir/scripts/path-setup.sh" ]]; then
    # shellcheck source=scripts/path-setup.sh
    source "$script_dir/scripts/path-setup.sh"
    return
  fi

  path_setup_url="https://raw.githubusercontent.com/$REPO/$BRANCH/scripts/path-setup.sh"
  curl -fsSL "$path_setup_url" -o "$tmpdir/path-setup.sh"
  # shellcheck source=/dev/null
  source "$tmpdir/path-setup.sh"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

main "$@"
