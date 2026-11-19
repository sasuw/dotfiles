#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: convert_list_to_sql_in_list.sh <file-or-multiline-string>

Print a parenthesized list of SQL string literals.
Trim surrounding whitespace, omit blank lines, and double single quotes.
EOF
}

process_entries() {
  local input="$1"
  local entry
  local escaped_entry
  local separator=""
  local result="("

  while IFS= read -r entry; do
    entry=$(printf '%s' "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') || return
    if [[ -n "$entry" ]]; then
      escaped_entry=${entry//\'/\'\'}
      result+="${separator}'${escaped_entry}'"
      separator=", "
    fi
  done <<< "$input"

  printf '%s)\n' "$result"
}

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

if ! command -v sed >/dev/null 2>&1; then
  printf 'convert_list_to_sql_in_list.sh: sed is required\n' >&2
  exit 1
fi

if [[ -f "$1" ]]; then
  input=$(< "$1") || exit
else
  input="$1"
fi

process_entries "$input"
