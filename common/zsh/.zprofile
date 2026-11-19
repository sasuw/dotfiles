#Run by login shells (see https://zsh.sourceforge.io/Doc/Release/Files.html)

logger "ZDOT .zprofile started" 2>/dev/null || true

# ~/.local/bin is added by .zshenv for every zsh, including the plain `zsh -c`
# that sshd runs for `ssh host '<cmd>'` (not a login shell, so it never reads
# this file). It is added again here because on macOS /etc/zprofile runs
# path_helper after .zshenv and moves user entries behind the system ones.
# .zshenv's `typeset -U PATH` drops the duplicate.
if [ -d "$HOME/.local/bin" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

