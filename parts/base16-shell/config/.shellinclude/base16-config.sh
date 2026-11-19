# Base16 Shell: the active theme is persisted in the ~/.base16_theme symlink
# by profile_helper.sh and re-applied on every shell start. Switch themes with
# base16_<name>; executables in $BASE16_SHELL_HOOKS then run automatically
# (e.g. syncing the GNOME Terminal default profile, see
# ~/.config/base16-shell-hooks/sync_gnome_terminal.sh).
#
# BASE16_DEFAULT_THEME is only used when no theme has been chosen yet on this
# machine. Hosts can pre-set it in a file sourced before this one
# (e.g. .shellinclude/00-base16-default-<host>.sh).
export BASE16_SHELL="$HOME/.config/base16-shell"
export BASE16_SHELL_HOOKS="$HOME/.config/base16-shell-hooks"
export BASE16_DEFAULT_THEME="${BASE16_DEFAULT_THEME:-atelier-savanna}"

[ -n "$PS1" ] && \
    [ -s "$BASE16_SHELL/profile_helper.sh" ] && \
        source "$BASE16_SHELL/profile_helper.sh"

#Favorites (dark):

#papercolor-dark
#phd
#twilight
#brogrammer
#brushtrees-dark
#greenscreen
#oceanicnext

#Favorites (light):

#brushtrees
