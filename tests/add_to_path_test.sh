#!/usr/bin/env bash
# Real CLI/runtime tests; no fake tools, network, or user startup files.
set -euo pipefail

case "${1:-}" in
  -h|--help)
    printf 'Usage: add_to_path_test.sh [-h|--help]\n\nRun isolated PATH persistence and Git regression tests.\n'
    exit 0
    ;;
  '') ;;
  *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
PYTHON_BIN="$(command -v python3)"
ZSH_BIN="$(command -v zsh)"
GIT_BIN="$(command -v git)"
exec env -i PATH=/usr/bin:/bin TMPDIR="${TMPDIR:-/tmp}" "$PYTHON_BIN" -B \
  "$REPO_ROOT/tests/lib/add_to_path_cases.py" "$ZSH_BIN" "$GIT_BIN"
