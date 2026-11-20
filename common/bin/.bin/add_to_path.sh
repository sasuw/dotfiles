#!/usr/bin/env zsh
# Persist a directory in interactive zsh's PATH. See add_to_path.sh --help.

set -euo pipefail

script_name="${0:t}"
source "${0:A:h}/lib/dotfiles_edit_lib.zsh"

usage() {
  cat <<HELP
Usage: $script_name [OPTIONS] DIRECTORY

Save a guarded PATH addition in an explicitly selected layer, source or file.
Append by default; existing PATH entries keep their position on reload.
Relative directories are resolved against the current working directory.
Paths under HOME are saved with a runtime HOME prefix; other text is literal.

Options:
      --prepend   Add before existing PATH entries instead of after them
      --layer-root DIR  Select a layer and its standard PATH include
      --source ID       Select the layer root registered as source.ID in
                        \${XDG_CONFIG_HOME:-\$HOME/.config}/dotfiletracker/config;
                        its include is common/shellutil/.shellinclude/
                        zz-ID-paths.sh if present, else path_additions.sh
  -f, --file FILE       Save to an explicit existing shell include file;
                        with --layer-root or --source, FILE must be inside
                        that root and its Git repository
  -n, --dry-run    Preview the entry and Git actions; change nothing
      --no-git     Save only; skip staging, committing, and pushing
      --           End options; required before a DIRECTORY starting with -
  -h, --help       Show this help

Name --layer-root, --source or --file; --source excludes --layer-root.
By default FILE must be tracked and unchanged. Commit only FILE and push
the current branch. Missing directories are saved but skipped at startup.
An identical saved entry is a no-op; edit FILE to change saved ordering.
Reload interactive zsh with soz afterwards. Other shells are not configured.

Examples:
  $script_name --layer-root ~/dotfiles ~/tools/bin
  $script_name --source personal ~/tools/bin
  $script_name --file ~/private/paths.sh --prepend /opt/example/bin
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

ensure_path_commands() {
  local cmd
  for cmd in cat tail zsh; do
    (( $+commands[$cmd] )) || die "required command not found: $cmd"
  done
}

# EXPR is already shell-quoted data, optionally prefixed by literal "$HOME".
path_entry_block() {
  local expr="$1" placement="$2" assignment
  if [[ "$placement" == prepend ]]; then
    assignment="${expr}\"\${PATH:+:\$PATH}\""
  else
    assignment="\"\${PATH:+\$PATH:}\"${expr}"
  fi
  print -r -- "if [ -d $expr ]; then
  case \":\${PATH-}:\" in
    *:$expr:*) ;;
    *) export PATH=$assignment ;;
  esac
fi"
}

main() {
  local placement=append dry_run=0 use_git=1 file=''
  local dotfiles_edit_layer_option='' dotfiles_edit_file_option='' dotfiles_edit_source_option=''
  while (( $# )); do
    case "$1" in
      --prepend) placement=prepend; shift ;;
      --layer-root|-f|--file|--file=*|--source|--source=*)
        dotfiles_edit_parse_destination_option "$@"
        shift "$REPLY" ;;
      -n|--dry-run) dry_run=1; shift ;;
      --no-git) use_git=0; shift ;;
      -h|--help) usage; return 0 ;;
      --) shift; break ;;
      -*) usage_error "unknown option: $1" ;;
      *) break ;;
    esac
  done
  (( $# == 1 )) || usage_error "expected one DIRECTORY, got $# argument(s)"
  ensure_path_commands
  local directory="$1"
  [[ -n "$directory" ]] || usage_error 'DIRECTORY is empty'
  [[ "$directory" != *:* && "$directory" != *$'\n'* && "$directory" != *$'\r'* ]] \
    || usage_error 'DIRECTORY must not contain colons or line breaks'
  local dotfiles_edit_file dotfiles_edit_layer dotfiles_edit_root dotfiles_edit_relative
  local dotfiles_edit_branch dotfiles_edit_remote
  dotfiles_edit_select_file "$dotfiles_edit_layer_option" "$dotfiles_edit_file_option" \
    'common/shellutil/.shellinclude/path_additions.sh' "$dotfiles_edit_source_option" paths
  file="$dotfiles_edit_file"

  # :a makes a lexical absolute path without resolving symlinks (:A would).
  directory="${directory:a}"
  local home_dir="${HOME:a}" expr suffix
  [[ "$directory" != *:* && "$directory" != *$'\n'* && "$directory" != *$'\r'* ]] \
    || usage_error 'resolved DIRECTORY must not contain colons or line breaks'
  if [[ "$directory" == "$home_dir" ]]; then
    expr='"$HOME"'
  elif [[ "$directory" == "${home_dir%/}/"* ]]; then
    suffix="${directory#"${home_dir%/}"}"
    expr='"$HOME"'"${(qq)suffix}"
  else
    expr="${(qq)directory}"
  fi

  local block other_block contents other_placement=prepend
  [[ "$placement" != prepend ]] || other_placement=append
  block="$(path_entry_block "$expr" "$placement")"
  other_block="$(path_entry_block "$expr" "$other_placement")"
  contents=$'\n'"$(<"$file")"$'\n'
  if [[ "$contents" == *$'\n'"$other_block"$'\n'* ]]; then
    die "DIRECTORY is already saved with $other_placement ordering; edit $file to change it"
  fi
  if [[ "$contents" == *$'\n'"$block"$'\n'* ]]; then
    print -r -- "DIRECTORY is already saved in $file; nothing changed."
    print -r -- 'Run soz to load saved entries in this shell.'
    return 0
  fi
  [[ -d "$directory" ]] \
    || print -u2 -r -- "$script_name: warning: directory does not exist; startup will skip it: $directory"

  local prefix=$'\n'
  [[ ! -s "$file" || -z "$(tail -c 1 -- "$file")" ]] || prefix=$'\n\n'
  [[ -s "$file" ]] || prefix=''
  if ! { cat -- "$file"; print -rn -- "$prefix$block"$'\n'; } | zsh -n; then
    die 'the result would not pass zsh -n; changes were not saved'
  fi

  if (( use_git )); then
    dotfiles_edit_prepare_git "$file"
    file="$dotfiles_edit_file"
  fi
  if (( dry_run )); then
    print -r -- "Would append to $file:"
    print -r -- "$block"
    (( ! use_git )) || dotfiles_edit_preview_git
    return 0
  fi
  print -rn -- "$prefix$block"$'\n' >>"$file"
  print -r -- "Appended to $file:"
  print -r -- "$block"
  (( ! use_git )) || dotfiles_edit_publish "path: $placement $expr" entry
  print -r -- 'Run soz to load it in this shell.'
}

main "$@"
