# Initialize completion once per shell.
#
# Within 24 hours of the last full check, load ~/.zcompdump without checks
# (compinit -C, ~15 ms). Otherwise run the checked compinit: it runs compaudit,
# rescans $fpath when the number of completion files changed, and rewrites the
# dump. The touch restarts the 24-hour window when the dump was still valid.
#
# Completions installed in the meantime appear after that window, or at once
# after `rm ~/.zcompdump` and a new shell.
#
# Pass compinit flags separately: it stops parsing at a combined "-CD".
() {
  setopt local_options extended_glob

  if (( ${+functions[compdef]} ))
  then
    return 0
  fi

  local zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"

  autoload -Uz compinit

  if [[ -n ${zcompdump}(#qN.mh-24) ]]
  then
    compinit -C -d "$zcompdump"
  else
    compinit -d "$zcompdump" && touch "$zcompdump"
  fi
}
