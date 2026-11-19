#!/usr/bin/env zsh
# Keep the GNOME Terminal default profile in sync with the current base16
# shell theme (~/.base16_theme symlink).
#
# Runs automatically after every base16_<theme> switch: profile_helper.sh of
# base16-shell executes every executable in $BASE16_SHELL_HOOKS. Can also be
# run manually. Exits silently when dconf/GNOME Terminal is not around, so it
# is safe on non-GNOME hosts.

set -eu

script_name="${0:t}"
base_key="/org/gnome/terminal/legacy/profiles:"
color_scripts_dir="$HOME/.config/base16-gnome-terminal/color-scripts"
theme_link="$HOME/.base16_theme"
dry_run=false

usage() {
  cat <<EOF
Usage: ${script_name} [-n|--dry-run] [-h|--help]

Sync the GNOME Terminal default profile to the base16 theme currently
selected for the shell (symlink ~/.base16_theme).

If no matching profile exists yet, the corresponding color script from
base16-gnome-terminal creates one (cloned from the current default profile,
so font/scrollback settings carry over). The matching profile is then set as
the default, so new terminal windows open with the right colors and there is
no flash at startup.

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

# Nothing to do on hosts without dconf/GNOME Terminal or before a theme was chosen.
command -v dconf >/dev/null 2>&1 || exit 0
[[ -h "$theme_link" ]] || exit 0

theme_script="$(readlink "$theme_link")"
theme="${${theme_script:t}%.sh}" # e.g. base16-ashes

# Lowercase and strip everything but alphanumerics, so the theme name can be
# compared with the profile visible-name ("base16-ashes-256" vs "Base 16 Ashes 256").
normalize() {
  local s="${(L)1}"
  print -r -- "${s//[^[:alnum:]]/}"
}

wanted="$(normalize "${theme}-256")"

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
  echo "${script_name}: no GNOME Terminal profiles in dconf yet; open Preferences once, then re-run base16_${theme#base16-}" >&2
  exit 0
fi

uuid="$(find_profile_uuid)" || uuid=""

if [[ -z "$uuid" ]]; then
  color_script="$color_scripts_dir/${theme}-256.sh"
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
