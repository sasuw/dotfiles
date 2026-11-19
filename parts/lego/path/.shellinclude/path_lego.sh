#!/usr/bin/env zsh

# Put the lego that LEGO_VERSION (common/zsh/.zshvars, the only pin) names on PATH:
# ${LEGO_INSTALL_ROOT:-/opt}/lego_v<version>_<os>_<arch>, the layout of the
# upstream release archives. An explicit choice, not the newest install:
# staging another version under /opt changes nothing until LEGO_VERSION
# changes. rules/lego sources this file too, so it
# stays valid bash. No forks: OSTYPE and CPUTYPE (zsh) or HOSTTYPE (bash).
LEGO_DIR=
if [[ -n "${LEGO_VERSION:-}" ]]; then
  lego_path_os="${OSTYPE%%[0-9-]*}"
  case "${CPUTYPE:-${HOSTTYPE:-}}" in
    x86_64|amd64) lego_path_arch=amd64 ;;
    aarch64|arm64) lego_path_arch=arm64 ;;
    *) lego_path_arch="${CPUTYPE:-${HOSTTYPE:-unknown}}" ;;
  esac
  LEGO_DIR="${LEGO_INSTALL_ROOT:-/opt}/lego_v${LEGO_VERSION}_${lego_path_os}_${lego_path_arch}"
  unset lego_path_os lego_path_arch
  [[ -x "$LEGO_DIR/lego" ]] && export PATH="$LEGO_DIR:$PATH"
fi
