#!/usr/bin/env zsh

timestamp_print(){
  local timestamp=$(date +%y%m%d_%H%M%S)
  echo $timestamp
}
alias tsp=timestamp_print

date_read_yyyymmdd() {
  local arg="$1"

  # 1. no argument -> today
  if [[ -z "$arg" ]]; then
    date +%F
    return
  fi

  # 2. already a YYYY-MM-DD date -> return as is
  if [[ "$arg" =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]]; then
    print -r -- "$arg"
    return
  fi

  # 3. integer offset from today
  if [[ "$arg" =~ '^-?[0-9]+$' ]]; then
    date -d "$arg days" +%F
    return
  fi

  print -u2 "date_read_yyyymmdd: invalid argument: $arg"
  return 1
}