#!/bin/bash

# Directories to check
DIR1="$HOME/.acme.sh/"

if [[ -d "$DIR1" ]]; then
  exit 0
else
  exit 1
fi
