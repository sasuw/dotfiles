#!/bin/zsh

# Debug flag
DEBUG=false

# Debug print helper
function debug() {
  if [[ "$DEBUG" == true ]]; then
    echo "[DEBUG] $1"
  fi
}

# Determine OS category from $OSTYPE
function map_ostype() {
  local ostype="$OSTYPE"
  case "$ostype" in
    linux-gnu* | linux-gnueabihf*) echo "linux" ;;
    darwin*) echo "macos" ;;
    freebsd* | netbsd* | openbsd*) echo "bsd" ;;
    *) echo "unknown" ;;
  esac
}

export OS_CATEGORY="$(map_ostype)"
export PC_NAME="$(hostname)"

fmt_bold() {
  print -nr -- "$(tput bold)"
}

fmt_reset() {
  print -nr -- "$(tput sgr0)"
}

measure() {
  local cmd_to_execute="$*"
  local start=$EPOCHREALTIME
  "$@"
  local command_exit_code=$?
  local end=$EPOCHREALTIME
  printf "Execution time of $(fmt_bold)""${cmd_to_execute}""$(fmt_reset)"": %.6f seconds\n" "$(( end - start ))"
  return "$command_exit_code"
}

# Source all .sh/.zsh files from a subdirectory under $HOME
function source_all_sh_files_in_subdir_of_home() {
  local subdir="$1"
  local start

  if [[ "$DEBUG" == true ]]; then
    start=$EPOCHREALTIME
  fi

  debug "Starting source_all_sh_files_in_subdir_of_home with subdir '$subdir'"

  if [[ -z "$subdir" ]]; then
    echo "Error: subdir is unset or empty" >&2
    return 1
  fi

  # Add $HOME/ prefix only if not already present
  if [[ "$subdir" != "$HOME/"* ]]; then
    subdir="$HOME/$subdir"
  fi

  debug "Final subdir path: $subdir"
  if [[ ! -d "$subdir" ]]; then
    echo "Error: Directory does not exist: $subdir" >&2
    return 1
  fi

  # Enable null_glob only within this function (zsh-specific)
  if [[ -n "$ZSH_VERSION" ]]; then
    setopt localoptions null_glob
  fi

  if [[ "$DEBUG" == true ]]; then
    printf "source_all_sh_files_in_subdir_of_home preparation time: %.6f seconds\n" "$(( EPOCHREALTIME - start ))"
  fi

  # Loop over matching files; if none exist, the guard skips sourcing
  local file
  for file in "$subdir"/*.sh "$subdir"/*.zsh; do
    [[ -e "$file" ]] || continue
    debug "Sourcing $file"

    if [[ "$DEBUG" == true ]]; then
      start=$EPOCHREALTIME
    fi

    # Source through a named function (not an anonymous `() { ... } "$file"`
    # call, which is zsh-only syntax and a bash syntax error) so the file does
    # not inherit this function's directory argument as its own positional
    # parameter. common.sh is zsh-only overall, but this file also gets
    # sourced from bash-shebang callers like dotfiletracker/envmaker.sh when
    # invoked under a bash login shell (e.g. root on hosts where root's shell
    # is bash), so this one construct must parse under both.
    _source_one_file_isolated() {
      local source_file="$1"
      shift
      . "$source_file"
    }
    _source_one_file_isolated "$file"
    unset -f _source_one_file_isolated

    if [[ "$DEBUG" == true ]]; then
      printf "!!! Source execution time: %.6f seconds\n" "$(( EPOCHREALTIME - start ))"
    fi
  done

  return 0
}

# Source local environment files depending on host and OS
function source_localenv_files() {
  local env_type="$1"
  local localenv_pc_dir="$HOME/.localenv-${env_type}-pc-${PC_NAME}"
  local localenv_os_dir="$HOME/.localenv-${env_type}-os-${OS_CATEGORY}"

  debug "Checking for PC-specific env: $localenv_pc_dir"
  if [[ -d "$localenv_pc_dir" ]]; then
    source_all_sh_files_in_subdir_of_home "$localenv_pc_dir" || return $?
  fi

  debug "Checking for OS-specific env: $localenv_os_dir"
  if [[ -d "$localenv_os_dir" ]]; then
    source_all_sh_files_in_subdir_of_home "$localenv_os_dir" || return $?
  fi
}

# Source non-interactive localenv files
function source_localenv_non_interactive_files() {
  debug "Calling source_localenv_non_interactive_files"
  source_localenv_files "noninteractive"
}

# Source interactive localenv files
function source_localenv_interactive_files() {
  debug "Calling source_localenv_interactive_files"
  source_localenv_files "interactive"
}
