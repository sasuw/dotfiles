#!/usr/bin/env zsh

backup_paths_reverse() {
  emulate -L zsh
  setopt localoptions extendedglob

  local -a items
  items=("$@")

  local item rel target_dir

  # Loop backwards through arguments
  local i
  for (( i = $#items; i >= 1; i-- )); do
    item=${items[i]}

    # Stop at the first non-existing/non-file/non-directory argument
    if [[ ! -f "$item" && ! -d "$item" ]]; then
      break
    fi

    # Get path relative to current working directory
    rel=${item:A}
    rel=${rel#$PWD/}

    # Reject paths outside the current working directory
    if [[ "$rel" == "$rel:A" ]]; then
      print -u2 "Skipping path outside current directory: $item"
      continue
    fi

    if [[ -f "$item" ]]; then
      target_dir="$BACKUP_ROOT/${rel:h}"
      mkdir -p -- "$target_dir" || return 1
      cp -- "$item" "$target_dir/" || return 1
    elif [[ -d "$item" ]]; then
      mkdir -p -- "$BACKUP_ROOT/$rel" || return 1
    fi
  done
}

rm_with_backup(){
  backup_paths_reverse "$@"
  echo "Would rm now"
}
