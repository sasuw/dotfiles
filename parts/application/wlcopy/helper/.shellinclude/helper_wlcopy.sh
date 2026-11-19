#!/usr/bin/env zsh

copy-line-to-clipboard() {
  print -rn -- "$BUFFER" | wl-copy
}
zle -N copy-line-to-clipboard
# Alt+c
bindkey -M emacs '^[c' copy-line-to-clipboard
bindkey -M vicmd '^[c' copy-line-to-clipboard
