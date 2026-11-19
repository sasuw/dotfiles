#!/usr/bin/env zsh

firefox_open() {
  local option=""
  local website=""

  # if first argument is -nw, shift
  if [[ "$1" == "-nw" ]]; then
    option="-new-window"
    shift
  fi

  website="$1"
  if [[ -z "$website" ]]; then
    echo "Usage: firefox_open [-nw] <url>"
    return 1
  fi

  nohup firefox $option "$website" >/dev/null 2>&1 & disown
}
