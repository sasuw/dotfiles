#!/usr/bin/env zsh
# Keep the GNOME Terminal default profile in sync with the current base16/tinty
# theme.
#
# Runs automatically after every theme switch via tinty hooks. Can also be
# run manually. Exits silently when dconf/GNOME Terminal is not around, so it
# is safe on non-GNOME hosts.

set -eu

script_name="${0:t}"
base_key="/org/gnome/terminal/legacy/profiles:"
theme_link="$HOME/.base16_theme"
tinty_scheme_file="$HOME/.local/share/tinted-theming/tinty/current_scheme"
dry_run=false

usage() {
  cat <<EOF
Usage: ${script_name} [-n|--dry-run] [-h|--help]

Sync the GNOME Terminal default profile to the theme currently
selected via tinty or base16-shell.

Options:
  -n, --dry-run  Show what would be done without changing anything
  -h, --help     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# Nothing to do on hosts without dconf/GNOME Terminal.
command -v dconf >/dev/null 2>&1 || exit 0

if [[ -n "${TINTY_SCHEME_ID:-}" || -r "$tinty_scheme_file" ]]; then
  if [[ -n "${TINTY_SCHEME_ID:-}" ]]; then
    theme="$TINTY_SCHEME_ID"
  else
    theme="$(<"$tinty_scheme_file")"
  fi
  color_script="$HOME/.local/share/tinted-theming/tinty/base16-gnome-terminal-color-scripts-file.sh"
  normalize() {
    local s="${(L)1}"
    print -r -- "${s//[^[:alnum:]]/}"
  }
  wanted="$(normalize "${theme}")"
else
  [[ -h "$theme_link" ]] || exit 0
  theme_script="$(readlink "$theme_link")"
  theme="${${theme_script:t}%.sh}" # e.g. base16-ashes
  color_script="$HOME/.config/base16-gnome-terminal/color-scripts/${theme}-256.sh"
  normalize() {
    local s="${(L)1}"
    print -r -- "${s//[^[:alnum:]]/}"
  }
  wanted="$(normalize "${theme}-256")"
fi

find_profile_uuid() {
  local line uuid name
  for line in ${(f)"$(dconf list "$base_key/" 2>/dev/null)"}; do
    [[ "$line" == :*/ ]] || continue
    uuid="${${line#:}%/}"
    name="$(dconf read "$base_key/:$uuid/visible-name" 2>/dev/null)"
    name="${name//\'/}"
    if [[ "$(normalize "$name")" == "$wanted" ]]; then
      print -r -- "$uuid"
      return 0
    fi
  done
  return 1
}

# The upstream color scripts fall back to gconf when no dconf profile list
# exists yet (fresh GNOME Terminal). Require one existing profile instead.
if [[ -z "$(dconf list "$base_key/" 2>/dev/null)" ]]; then
  echo "${script_name}: no GNOME Terminal profiles in dconf yet; open Preferences once, then re-run theme switch" >&2
  exit 0
fi

uuid="$(find_profile_uuid)" || uuid=""

if [[ -z "$uuid" ]]; then
  if [[ ! -f "$color_script" ]]; then
    echo "${script_name}: $color_script not found, skipping GNOME Terminal sync" >&2
    exit 0
  fi
  if $dry_run; then
    echo "would create profile via $color_script and set it as default"
    exit 0
  fi
  bash "$color_script"
  uuid="$(find_profile_uuid)" || {
    echo "${script_name}: no profile matching '$theme' found after running $color_script" >&2
    exit 1
  }
fi

current_default="$(dconf read "$base_key/default" 2>/dev/null)"
current_default="${current_default//\'/}"
if [[ "$current_default" == "$uuid" ]]; then
  exit 0 # already in sync
fi

if $dry_run; then
  echo "would set GNOME Terminal default profile to $uuid (${theme}-256)"
  exit 0
fi

dconf write "$base_key/default" "'$uuid'"
echo "GNOME Terminal default profile set to ${theme}-256 (applies to new windows)"
