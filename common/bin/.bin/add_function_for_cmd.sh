#!/usr/bin/env zsh
#
# Append a shell function (or alias) to an explicitly selected layer or file.
# See add_function_for_cmd.sh --help.

set -euo pipefail

script_name="${0:t}"
# Resolve the stowed script link to locate the shared editing library.
repo_root="${0:A:h:h:h:h}"
source "${0:A:h}/lib/dotfiles_edit_lib.zsh"

usage() {
  cat <<HELP
Usage: $script_name [OPTIONS] NAME COMMAND

Append a function NAME that runs COMMAND to an explicitly selected file:

  function NAME(){
    COMMAND
  }

Quote COMMAND as one argument. Every COMMAND line is indented by two spaces.

Options:
  -a, --alias      Write alias NAME='COMMAND' instead of a function
  -A, --pass-args  Append "\$@" to COMMAND, so NAME forwards its arguments
                   (a function only; an alias always forwards them)
      --layer-root DIR  Select a layer and its standard aliases include
  -f, --file FILE       Write to an explicit existing shell include file
      --force      Allow a NAME that is already a command, builtin, or
                   reserved word for zsh
  -n, --dry-run    Print the definition and target file; change nothing
      --no-git     Append only; skip staging, committing, and pushing
  -h, --help       Show this help

The run is refused when NAME is invalid, NAME is already defined in this
repository's shell files (or in FILE), or the file would not pass zsh -n.
By default, stage and commit only FILE, then push the current branch to its
push remote (falling back to origin). FILE must be tracked and unchanged.
Reload interactive shells with soz afterwards.

Example:
  $script_name --layer-root ~/dotfiles gitroot 'git rev-parse --show-toplevel'
HELP
}

die() {
  print -u2 -r -- "$script_name: $*"
  exit 1
}

usage_error() {
  print -u2 -r -- "$script_name: $*"
  print -u2 -r -- "Run '$script_name --help' for usage."
  exit 2
}

# Prints each definition of $1 (function, name(), or alias) in the given files.
find_definitions() {
  local name="$1"; shift
  local quoted="${name//./\\.}"
  # An alias can quote its name alone or the entire NAME=COMMAND argument.
  local pattern="^[[:space:]]*(function[[:space:]]+${quoted}([[:space:]]*\\(\\))?([[:space:]]|\\{|\$)|${quoted}[[:space:]]*\\(\\)|alias([[:space:]]+-[a-zA-Z]+)*[[:space:]]+['\"]?${quoted}['\"]?=)"
  (( $# )) || return 1
  grep -HnE -- "$pattern" "$@"
}

# The shell files of the repository that define functions and aliases.
repo_shell_files() {
  local repo_root="$1"
  local -a files
  files=(
    "$repo_root"/(common|parts)/**/.shellinclude/**/*(.N)
    "$repo_root"/common/zsh/.zsh(rc|env)(.N)
    "$repo_root"/common/bash/.bash(rc|_profile)(.N)
  )
  print -rl -- $files
}

main() {
  local as_alias=0 pass_args=0 force=0 dry_run=0 use_git=1 file='' layer='' file_set=0 layer_set=0
  while (( $# )); do
    case "$1" in
      -a|--alias) as_alias=1; shift ;;
      -A|--pass-args) pass_args=1; shift ;;
      --layer-root)
        (( $# >= 2 )) || usage_error "$1 needs a directory"
        (( ! layer_set )) || usage_error 'layer root was specified more than once'
        [[ -n "$2" ]] || usage_error 'layer root is empty'
        layer_set=1
        layer="$2"; shift 2 ;;
      -f|--file)
        (( $# >= 2 )) || usage_error "$1 needs a file"
        (( ! file_set )) || usage_error 'file was specified more than once'
        [[ -n "$2" ]] || usage_error 'file is empty'
        file_set=1
        file="$2"; shift 2 ;;
      --file=*)
        (( ! file_set )) || usage_error 'file was specified more than once'
        file="${1#--file=}"
        [[ -n "$file" ]] || usage_error 'file is empty'
        file_set=1; shift ;;
      --force) force=1; shift ;;
      -n|--dry-run) dry_run=1; shift ;;
      --no-git) use_git=0; shift ;;
      -h|--help) usage; return 0 ;;
      --) shift; break ;;
      -*) usage_error "unknown option: $1" ;;
      *) break ;;
    esac
  done
  (( $# == 2 )) || usage_error "expected NAME and COMMAND, got $# argument(s)"
  local name="$1" cmd="$2"

  [[ "$name" =~ '^[A-Za-z_][A-Za-z0-9_.-]*$' ]] \
    || die "invalid name '$name': use letters, digits, '_', '.', '-', not starting with a digit, '.' or '-'"
  [[ "$cmd" == *[^[:space:]]* ]] || die 'COMMAND is empty'
  local dotfiles_edit_file dotfiles_edit_root dotfiles_edit_relative
  local dotfiles_edit_branch dotfiles_edit_remote
  dotfiles_edit_select_file "$layer" "$file" 'common/alias/.shellinclude/aliases.sh'
  file="$dotfiles_edit_file"
  local search_root="${layer:A}"
  if [[ -z "$layer" ]]; then
    search_root="$(git -C "${file:h}" rev-parse --show-toplevel 2>/dev/null)" || search_root="${file:h}"
  fi
  if (( as_alias )); then
    (( ! pass_args )) || usage_error '--pass-args applies to functions only'
    [[ "$cmd" != *$'\n'* ]] || die 'an alias must be a single line; omit --alias for a function'
  fi

  local -a search_files
  search_files=("$file" ${(f)"$(repo_shell_files "$search_root")"} ${(f)"$(repo_shell_files "$repo_root")"})
  local existing
  if existing="$(find_definitions "$name" ${(u)search_files})"; then
    die "'$name' is already defined:"$'\n'"$existing"
  fi

  local kind
  kind="$(whence -w -- "$name" 2>/dev/null)" && kind="${kind#*: }" || kind=''
  if [[ -n "$kind" && "$kind" != none ]]; then
    (( force )) || die "'$name' is already a zsh $kind ($(whence -- "$name")); use --force to shadow it"
    print -u2 -r -- "$script_name: warning: '$name' shadows a zsh $kind"
  fi

  local block
  if (( as_alias )); then
    block="alias $name=${(qq)cmd}"
  else
    (( ! pass_args )) || cmd+=' "$@"'
    local line
    block="function $name(){"
    for line in "${(@f)cmd}"; do
      block+=$'\n'"${line:+  }$line"
    done
    block+=$'\n}'
  fi

  # Keep one blank line between entries, also when the file lacks a final LF.
  local prefix=$'\n'
  [[ ! -s "$file" || -z "$(tail -c 1 -- "$file")" ]] || prefix=$'\n\n'
  [[ -s "$file" ]] || prefix=''

  if ! { cat -- "$file"; print -rn -- "$prefix$block"$'\n'; } | zsh -n 2>/dev/null; then
    die "the result would not pass zsh -n; check the quoting of COMMAND:"$'\n'"$block"
  fi

  if (( use_git )); then
    dotfiles_edit_prepare_git "$file"
    file="$dotfiles_edit_file"
  fi

  if (( dry_run )); then
    print -r -- "Would append to $file:"
    print -r -- "$block"
    if (( use_git )); then
      dotfiles_edit_preview_git
    fi
    return 0
  fi
  print -rn -- "$prefix$block"$'\n' >>"$file"
  print -r -- "Appended to $file:"
  print -r -- "$block"
  if (( use_git )); then
    dotfiles_edit_publish "alias: add $name" definition
  fi
  print -r -- "Run soz to load it in this shell."
}

main "$@"
