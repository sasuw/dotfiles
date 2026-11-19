#!/usr/bin/env zsh

tree() {
  command tree --prune -I '*~' "$@"
}
