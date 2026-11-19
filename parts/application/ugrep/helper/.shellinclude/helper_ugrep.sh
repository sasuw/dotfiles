#!/usr/bin/env zsh

ugrep_find_typos(){
  local word_to_find="$1"
  ugrep -i -R -Z1 "${word_to_find}" . | grep -v Binary | rg -v -i "${word_to_find}" | ugrep -i -o -Z1 "${word_to_find}" | sort | uniq
}