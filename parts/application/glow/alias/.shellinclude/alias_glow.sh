#!/usr/bin/env zsh

function gat(){
  glow -w "$((COLUMNS - 10))" "$@"
}

function gatp(){
  gat -p "$@"
}

