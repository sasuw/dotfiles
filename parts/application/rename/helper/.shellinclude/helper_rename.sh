#!/usr/bin/env zsh

_rename_fd() {
  if command -v fd >/dev/null 2>&1; then
    command fd "$@"
  elif command -v fdfind >/dev/null 2>&1; then
    command fdfind "$@"
  else
    print -u2 -- "Neither fd nor fdfind found in PATH"
    return 1
  fi
}

rename_found_files_replacing_pattern() {
  local pattern_old=$1
  local pattern_new=$2
  shift 2 2>/dev/null || return 1

  local dry_run=0 verbose=0 dir="."
  local -a ren_opts

  while (( $# )); do
    case "$1" in
      -n|--dry-run) dry_run=1 ;;
      -v|--verbose) verbose=1 ;;
      --) shift; break ;;
      -*) print -u2 -- "Unknown option: $1"; return 2 ;;
      *) dir="$1" ;;
    esac
    shift
  done

  [[ -d "$dir" ]] || { print -u2 -- "Not a directory: $dir"; return 1; }

  (( dry_run )) && ren_opts+=(-n)
  (( verbose )) && ren_opts+=(-v)

  _rename_fd -F -0 -tf -- "$pattern_old" "$dir" | while IFS= read -r -d '' f; do
    rename "${ren_opts[@]}" -- "$pattern_old" "$pattern_new" "$f"
  done
}

rename_found_files_removing_pattern() {
  local pattern=$1
  shift
  rename_found_files_replacing_pattern "$pattern" '' "$@"
}

# Rename files without extension recursively by appending detected extension.
#    Uses util-linux rename (string substitution).
#    Options:
#      -n, --dry-run   don't rename (passes -n)
#      -v, --verbose   show each old -> new (and passes -v)
rename_noext_recursive() {
  local dry_run=0 verbose=0 dir="."

  while (( $# )); do
    case "$1" in
      -n|--dry-run) dry_run=1 ;;
      -v|--verbose) verbose=1 ;;
      --) shift; break ;;
      -*) print -u2 -- "Unknown option: $1"; return 2 ;;
      *) dir="$1" ;;
    esac
    shift
  done

  [[ -d "$dir" ]] || { print -u2 -- "Not a directory: $dir"; return 1; }

  local -a ren_opts
  (( dry_run )) && ren_opts+=(-n)
  (( verbose )) && ren_opts+=(-v)
  ren_opts+=(--no-overwrite)

  local f base ext new_base new_path
  local -i renamed=0 skipped=0

  while IFS= read -r -d '' f; do
    base="${f:t}"                       # basename in zsh

    # Treat only a short trailing .suffix as a real extension. This allows
    # filenames like "Some Title. With extra text" to still be processed.
    if [[ "$base" =~ '\.[[:alnum:]]{1,9}$' ]]; then
      (( verbose )) && print -u2 -- "SKIP (has extension): $f"
      ((skipped++))
      continue
    fi

    ext="$(file_suggest_extension "$f")" || { ((skipped++)); continue; }

    new_base="${base}.${ext}"
    new_path="${f:h}/${new_base}"

    if [[ -e "$new_path" ]]; then
      (( verbose )) && print -u2 -- "SKIP (target exists): $f -> $new_path"
      ((skipped++))
      continue
    fi

    (( verbose )) && print -- "$f -> $new_path"

    # util-linux rename replaces first occurrence of "expression" with "replacement"
    # We replace the basename only.
    rename "${ren_opts[@]}" -- "$base" "$new_base" "$f" || {
      (( verbose )) && print -u2 -- "FAIL: $f"
      ((skipped++))
      continue
    }

    ((renamed++))
  done < <(_rename_fd --type f --exclude '.*' -0 . "$dir")

  (( verbose )) && print -u2 -- "Done. renamed=$renamed skipped=$skipped"
}
