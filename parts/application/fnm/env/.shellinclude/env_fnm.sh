#!/usr/bin/env zsh

export PATH="$HOME/.local/share/fnm:$PATH"
mkdir -p /tmp/fnm_multishells
export XDG_RUNTIME_DIR=/tmp
eval "$("$HOME/.local/share/fnm/fnm" env --use-on-cd)"
