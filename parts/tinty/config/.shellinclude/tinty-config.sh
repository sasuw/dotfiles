# Tinty Shell Theme Configuration
#
# Initializes the terminal theme using the Tinty CLI tool.
# Persists the theme across shell sessions and provides tab-completable
# aliases (e.g. base16_<theme>) to switch themes on the fly.
#
# BASE16_DEFAULT_THEME is only used when no theme has been chosen yet on this
# machine. Hosts can pre-set it in a file sourced before this one
# (e.g. .shellinclude/00-base16-default-<host>.sh).

local tinty_cmd="tinty"
if ! command -v tinty >/dev/null 2>&1; then
  if [[ -x "$HOME/.local/bin/tinty" ]]; then
    tinty_cmd="$HOME/.local/bin/tinty"
  else
    tinty_cmd=""
  fi
fi

if [[ -n "$PS1" ]] && [[ -n "$tinty_cmd" ]]; then
  # First-run initialization with default theme. Failures are reported rather
  # than swallowed: a missing item repo makes every apply fail, and silence
  # there just looks like "the colors are wrong on this host".
  if [[ ! -e "$HOME/.local/share/tinted-theming/tinty/current_scheme" ]]; then
    local default_theme="${BASE16_DEFAULT_THEME:-atelier-savanna}"
    default_theme="${default_theme#base16-}"
    "$tinty_cmd" apply "base16-$default_theme" >/dev/null 2>&1 ||
      echo "tinty: could not apply base16-$default_theme; try 'tinty install'" >&2
  else
    "$tinty_cmd" init >/dev/null 2>&1 ||
      echo "tinty: init failed; try 'tinty install'" >&2
  fi

  # Generate tab-completable base16_<theme> aliases
  if [[ -d "$HOME/.local/share/tinted-theming/tinty/repos/tinted-shell/scripts" ]]; then
    for script in "$HOME/.local/share/tinted-theming/tinty/repos/tinted-shell/scripts"/base16*.sh; do
      [[ -f "$script" ]] || continue
      script_name=${script##*/}
      script_name=${script_name%.sh}
      theme=${script_name#base16-}
      alias "base16_${theme}"="\"$tinty_cmd\" apply base16-${theme}"
    done
  else
    echo "tinty: tinted-shell scripts not installed; run 'tinty install'" >&2
  fi

  alias reset="command reset && \"$tinty_cmd\" init >/dev/null 2>&1"
fi
