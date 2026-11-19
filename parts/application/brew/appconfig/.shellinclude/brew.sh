export HOMEBREW_AUTO_UPDATE_SECS=86400
export HOMEBREW_NO_ENV_HINTS=1

# Set PATH, MANPATH, etc., for Homebrew (shared: parts/brew/lib/.bin/brew_shellenv.sh).
[ -r "$HOME/.bin/brew_shellenv.sh" ] && . "$HOME/.bin/brew_shellenv.sh"
