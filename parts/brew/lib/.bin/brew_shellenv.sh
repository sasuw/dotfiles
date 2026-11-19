# shellcheck shell=sh
# Shared POSIX Homebrew initialization for Linux, Intel macOS, and Apple Silicon.
# It is safe to source repeatedly and does nothing when brew is unavailable.

if [ -z "${HOMEBREW_SHELLENV_APPLIED-}" ]; then
  dotfiles_brew_bin=""

  if [ -n "${HOMEBREW_PREFIX-}" ] && [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then
    dotfiles_brew_bin="${HOMEBREW_PREFIX}/bin/brew"
  else
    for dotfiles_brew_candidate in \
      /home/linuxbrew/.linuxbrew/bin/brew \
      /opt/homebrew/bin/brew \
      /usr/local/bin/brew; do
      if [ -x "$dotfiles_brew_candidate" ]; then
        dotfiles_brew_bin="$dotfiles_brew_candidate"
        break
      fi
    done
  fi

  if [ -z "$dotfiles_brew_bin" ] && command -v brew >/dev/null 2>&1; then
    dotfiles_brew_bin=$(command -v brew)
  fi

  if [ -n "$dotfiles_brew_bin" ] && [ -x "$dotfiles_brew_bin" ]; then
    if [ -n "${ZSH_VERSION-}" ] && [ "$(id -u)" -eq 0 ] &&
       [ "$dotfiles_brew_bin" = /home/linuxbrew/.linuxbrew/bin/brew ]; then
      export HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
      export HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar
      export HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew
      export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin${PATH+:$PATH}"
      [ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}"
      export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH:-}"
    else
      if [ -n "${ZSH_VERSION-}" ]; then
        dotfiles_brew_shell="zsh"
      else
        dotfiles_brew_shell="sh"
      fi
      dotfiles_brew_env=$("$dotfiles_brew_bin" shellenv "$dotfiles_brew_shell") || {
        unset dotfiles_brew_bin dotfiles_brew_candidate dotfiles_brew_shell dotfiles_brew_env
        return 1
      }
      eval "$dotfiles_brew_env" || return 1
    fi
    export HOMEBREW_SHELLENV_APPLIED=1
  fi

  unset dotfiles_brew_bin dotfiles_brew_candidate dotfiles_brew_shell dotfiles_brew_env
fi
