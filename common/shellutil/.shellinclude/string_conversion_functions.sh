#!/usr/bin/env zsh

camel_to_snake() {
  local input="$1"
  echo "$input" \
    | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' \
    | sed -E 's/([A-Z])([A-Z][a-z])/\1_\2/g' \
    | tr '[:upper:]' '[:lower:]'
}

rename_camelcase_files_to_snakecase() {
  local filepath dir base new_base new_path search_root
  local mime description
  local -a old_paths new_paths
  local dry_run=0
  local only_shell_scripts=1

  search_root="."

  while (( $# )); do
    case "$1" in
      -n|--dry-run)
        dry_run=1
        ;;
      --all-files)
        only_shell_scripts=0
        ;;
      -h|--help)
        cat <<'EOF'
Usage: rename_camelcase_files_to_snakecase [OPTIONS] [PATH]

Rename files with CamelCase names to snake_case under PATH (default: current directory).

By default, only files identified as shell scripts by `file` are renamed.

Options:
  -n, --dry-run   Show planned renames without modifying files.
      --all-files Include non-shell files.
  -h, --help      Show this help.
EOF
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'Unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *)
        if [[ "$search_root" != "." ]]; then
          printf 'Only one PATH argument is supported.\n' >&2
          return 1
        fi
        search_root="$1"
        ;;
    esac
    shift
  done

  if (( $# > 1 )); then
    printf 'Only one PATH argument is supported.\n' >&2
    return 1
  fi

  if (( $# == 1 )); then
    if [[ "$search_root" != "." ]]; then
      printf 'Only one PATH argument is supported.\n' >&2
      return 1
    fi
    search_root="$1"
  fi

  if ! command -v fd >/dev/null 2>&1; then
    printf 'Missing required command: fd\n' >&2
    return 1
  fi

  if ! command -v file >/dev/null 2>&1; then
    printf 'Missing required command: file\n' >&2
    return 1
  fi

  if [[ ! -d "$search_root" ]]; then
    printf 'Path is not a directory: %s\n' "$search_root" >&2
    return 1
  fi

  while IFS= read -r filepath; do
    dir="${filepath:h}"
    base="${filepath:t}"
    new_base="$(camel_to_snake "$base")"
    new_path="${dir}/${new_base}"

    if [[ "$filepath" == "$new_path" ]]; then
      continue
    fi

    if [[ -e "$new_path" ]]; then
      printf 'Skipping (target exists): %s -> %s\n' "$filepath" "$new_path" >&2
      continue
    fi

    if (( only_shell_scripts )); then
      mime="$(file --brief --mime-type -- "$filepath" 2>/dev/null)"
      description="$(file --brief -- "$filepath" 2>/dev/null)"
      if [[ "$mime" != "text/x-shellscript" && "$mime" != "application/x-shellscript" && "${description:l}" != *"shell script"* ]]; then
        continue
      fi
    fi

    old_paths+=("$filepath")
    new_paths+=("$new_path")
  done < <(fd --type f '[A-Z]' "$search_root")

  if (( ${#old_paths} == 0 )); then
    printf 'No files matched for renaming under %s\n' "$search_root"
    return 0
  fi

  printf 'Planned renames (%d):\n' "${#old_paths}"
  for (( i = 1; i <= ${#old_paths}; i++ )); do
    printf '%s -> %s\n' "${old_paths[i]}" "${new_paths[i]}"
  done

  if (( dry_run )); then
    printf 'Dry run enabled, no files renamed.\n'
    return 0
  fi

  if [[ ! -t 0 ]]; then
    printf 'Refusing to rename without interactive confirmation (stdin is not a TTY).\n' >&2
    return 1
  fi

  printf 'Press y to continue, any other key to abort: '
  read -r -k 1 confirm_key
  printf '\n'
  if [[ "$confirm_key" != "y" && "$confirm_key" != "Y" ]]; then
    printf 'Aborted, no files renamed.\n'
    return 1
  fi

  for (( i = 1; i <= ${#old_paths}; i++ )); do
    mv -- "${old_paths[i]}" "${new_paths[i]}"
    printf 'Renamed: %s -> %s\n' "${old_paths[i]}" "${new_paths[i]}"
  done
}

string_print_codepoints() {
  local s c
  s=$*
  for c in ${(s::)s}; do
    printf 'U+%04X  %s\n' "'$c" "$c"
  done
}