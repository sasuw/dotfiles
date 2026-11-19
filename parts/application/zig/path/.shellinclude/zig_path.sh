#!/usr/bin/env zsh

zls_dir="/opt/zls-linux-x86_64-0.14.0"
if [[ -d "$zls_dir" ]]
then
  PATH="$PATH:$zls_dir"
fi
