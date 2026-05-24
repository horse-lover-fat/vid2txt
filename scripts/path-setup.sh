#!/usr/bin/env bash

LOCAL_BIN="${HOME}/.local/bin"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
PATH_MARKER="# Added by vid2txt installer"

ensure_local_bin_dir() {
  mkdir -p "$LOCAL_BIN"
}

path_configured() {
  local file
  for file in "${ZDOTDIR:-$HOME}/.zshrc" \
    "${ZDOTDIR:-$HOME}/.zprofile" \
    "$HOME/.bash_profile" \
    "$HOME/.bashrc" \
    "$HOME/.profile"; do
    if [[ -f "$file" ]] && grep -qs '\.local/bin' "$file"; then
      return 0
    fi
  done
  return 1
}

shell_config_for_path() {
  case "$(basename "${SHELL:-/bin/zsh}")" in
    bash)
      if [[ -f "$HOME/.bash_profile" ]]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    *)
      if [[ -f "${ZDOTDIR:-$HOME}/.zshrc" ]]; then
        echo "${ZDOTDIR:-$HOME}/.zshrc"
      else
        echo "${ZDOTDIR:-$HOME}/.zshrc"
      fi
      ;;
  esac
}

ensure_path_in_shell_configs() {
  if path_configured; then
    echo "~/.local/bin is already on PATH in your shell config."
    return 0
  fi

  local config
  config="$(shell_config_for_path)"
  touch "$config"

  {
    echo ""
    echo "$PATH_MARKER"
    echo "$PATH_LINE"
  } >> "$config"

  echo "Added ~/.local/bin to PATH in $config"
  echo "Open a new terminal window, then run: vid2txt --help"
}

needs_path_setup() {
  local dest="$1"
  [[ "$dest" == "$LOCAL_BIN/"* || "$dest" == "$LOCAL_BIN" ]]
}
