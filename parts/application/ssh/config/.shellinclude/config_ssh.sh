#!/usr/bin/env zsh

ssh() {
  local ssh_exit
  command ssh "$@"
  ssh_exit=$?

  if [[ -t 1 ]]; then
    printf '\033[0m\033]104\007\033]110\007\033]111\007\033]112\007'
  fi

  return "$ssh_exit"
}
