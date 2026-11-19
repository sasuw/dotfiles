# Shared Bash/zsh initialization. Optional personal policy precedes the neutral
# fallback; explicit nonempty caller overrides always win.
dotfiles_init_root() {
  local caller_root="${DOTFILE_DIR:-}"
  # Rule callers supply their own checkout; interactive startups keep the
  # neutral home default. A nonempty caller override always wins.
  if [ -z "${DOTFILE_DIR:-}" ] && [ -n "${1:-}" ]; then
    DOTFILE_DIR=$(CDPATH='' cd -- "$1" && pwd -P) || return
  fi
  # shellcheck source=/dev/null
  [ ! -r "$HOME/.shellinclude/00-personal-root.sh" ] || . "$HOME/.shellinclude/00-personal-root.sh"
  [ -z "$caller_root" ] || DOTFILE_DIR=$caller_root
  DOTFILE_DIR="${DOTFILE_DIR:-$HOME/dotfiles}"
  export DOTFILE_DIR
}
