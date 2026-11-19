#!/usr/bin/env zsh

fc_copy_line(){
  local line_number="${1:--1}"
  local event_number

  if [[ "$line_number" != -<-> && "$line_number" != <-> ]]; then
    print -u2 "fc_copy_line: expected a numeric history event, got: $line_number"
    return 1
  fi

  zmodload zsh/parameter || return 1

  if (( line_number < 0 )); then
    event_number="$(( HISTCMD + line_number ))"
  else
    event_number="$line_number"
  fi

  if [[ -z "${history[$event_number]+set}" ]]; then
    print -u2 "fc_copy_line: history event not found: $line_number"
    return 1
  fi

  print -rn -- "${history[$event_number]}" | setclip
}

alias fccl='fc_copy_line'
