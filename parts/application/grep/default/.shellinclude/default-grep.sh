#!/usr/bin/env zsh

unalias -m grep #in case it is aliased
unalias -m cgrep
cgrep() {
  command grep --color=always "$@"
}

_grep() {
  command grep
}

egrep() {
  command egrep --color=always "$@"
}

_egrep() {
  command egrep
}

igrep(){
  grep -i "$@"
}

extract_ip_address_from_start(){
  grep -Eo '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
}