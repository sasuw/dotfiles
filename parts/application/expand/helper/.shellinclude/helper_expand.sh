#!/usr/bin/env zsh

function expand_tabs_to_2_spaces_recursively(){
	local search_pattern="$1"
	local target_dir="$2"

	fd -0 "${search_pattern}" "${target_dir}" -tf | xargs -0 -I{} sh -c 'expand -t 2 "$1" | sudo sponge "$1"' sh {}
}

# Usage: expand_tabs_to_2_spaces_recursively "<fd-pattern>" "<directory>"
function expand_tabs_to_2_spaces_recursively() {
  emulate -L zsh
  setopt err_return        # on error, return from this function (don’t exit shell)
  setopt pipefail          # pipeline fails if any element fails

  # --- Validate arguments ---
  if [[ $# -ne 2 ]]; then
    print -u2 "Usage: expand_tabs_to_2_spaces_recursively <fd-pattern> <directory>"
    return 2
  fi

  local search_pattern="$1"
  local target_dir="$2"

  if [[ -z "$search_pattern" ]]; then
    print -u2 "Error: search pattern must not be empty."
    return 2
  fi
  if [[ ! -d "$target_dir" ]]; then
    print -u2 "Error: directory not found: $target_dir"
    return 2
  fi

  # --- Validate tools ---
  local cmd
  for cmd in fd expand sponge; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      print -u2 "Error: required command '$cmd' not found. Please install it."
      return 2
    fi
  done

  # --- Collect files (NUL-safe) ---
  local -a files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(fd -0 "${search_pattern}" "${target_dir}" -tf)

  if (( ${#files[@]} == 0 )); then
    print "No files matched pattern '${search_pattern}' under '${target_dir}'. Nothing to do."
    return 0
  fi

  # --- Determine if sudo is needed (any non-writable file) ---
  local need_sudo=0 f
  for f in "${files[@]}"; do
    [[ -w "$f" ]] || { need_sudo=1; break; }
  done

  # --- Preview & confirm ---
  print -- "Matched ${#files[@]} file(s):"
  for f in "${(@)files[1,10]}"; do print -- "  - $f"; done
  (( ${#files[@]} > 10 )) && print "  ... and $(( ${#files[@]} - 10 )) more"

  print
  print -- "Backups will be created under /tmp and tabs will be expanded to 2 spaces."
  (( need_sudo )) && print -- "Note: Some files are not writable; will use sudo for writes."
  printf "Proceed? [y/N] "
  local reply
  read -r reply || { print -u2 "Read aborted."; return 1; }
  [[ "$reply" == [Yy]* ]] || { print "Aborted."; return 0; }

  # --- Backup to /tmp (timestamped), preserving directory structure ---
  local ts backup_root
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_root="/tmp/expand-tabs-backup-${ts}"
  for f in "${files[@]}"; do
    mkdir -p "${backup_root}$(dirname "$f")" || return 1
    cp -p -- "$f" "${backup_root}${f}" || return 1
  done
  print -- "Backup created at: ${backup_root}"

  #this could be more sophisticated but it's ok I think
  local current_user=$(whoami)
  local not_current_user='!'"${current_user}"
  fd -0 --owner "${current_user}"      "${search_pattern}" "${target_dir}" -tf | xargs -0 -I{} sh -c 'expand -t 2 "$1" | sponge "$1"' sh {}
  fd -0 --owner "${not_current_user}"	 "${search_pattern}" "${target_dir}" -tf | xargs -0 -I{} sh -c 'expand -t 2 "$1" | sudo sponge "$1"' sh {}
}