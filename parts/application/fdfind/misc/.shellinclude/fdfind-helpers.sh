alias fd='fdfind'
alias fdf='fdfind -tf'
alias fd.='fdfind -H'
alias fdf.='fdfind -tf -H'
alias fd..='fdfind -HI'
alias fdf..='fdfind -tf -HI'

# Parse shared flags through zsh's dynamically scoped caller locals.
_fd_recent_options() {
  local arg end_options=0
  for arg in "$@"; do
    if (( end_options )); then
      recent_args+=("$arg")
    else
      case "$arg" in
        -a|--all) all_results=1 ;;
        --) end_options=1 ;;
        *) recent_args+=("$arg") ;;
      esac
    fi
  done
}

# Keep filenames intact and sort by numeric mtime, never by ls output.
_fd_recent_files() {
  local limit=$1 all_results=$2 file_type=$3 search_dir=$4 exclude_pattern=$5
  local found file_entry record grep_rc
  local -a fd_opts files records file_mtime
  zmodload zsh/stat || return
  (( all_results )) || fd_opts+=(--changed-within 7d)
  [[ -z $file_type ]] || fd_opts+=(-e "$file_type")
  found=$(fdfind -0 -t f "${fd_opts[@]}" -- . "$search_dir") || return
  [[ -n $found ]] || return 0
  files=("${(@0)found}")
  for file_entry in "${files[@]}"; do
    [[ -z $file_entry ]] && continue
    if [[ -n $exclude_pattern ]]; then
      if printf '%s\n' "$file_entry" | grep -q -- "$exclude_pattern"; then
        continue
      else
        grep_rc=$?
        (( grep_rc == 1 )) || return "$grep_rc"
      fi
    fi
    zstat -A file_mtime +mtime "$file_entry" || return
    records+=("${file_mtime[1]}:$file_entry")
  done
  records=("${(@On)records}")
  if (( ! all_results && ${#records} > limit )); then
    records=("${(@)records[1,limit]}")
  fi
  for record in "${records[@]}"; do
    printf '%s\0' "${record#*:}"
  done
}

_fd_recent_listing() {
  local found
  local -a files
  found=$(_fd_recent_files "$@") || return
  [[ -n $found ]] || return 0
  files=("${(@0)found}")
  files=("${(@)files:#}")
  # One listing lets ls calculate shared column widths for every result.
  ls -ldt -- "${files[@]}"
}

fd_latest_files_with_filetype(){
  local all_results=0
  local -a recent_args
  _fd_recent_options "$@"
  if (( ${#recent_args} < 1 || ${#recent_args} > 2 )); then
    printf 'Usage: fd_latest_files_with_filetype [-a|--all] FILETYPE [DIRECTORY]\n' >&2
    return 2
  fi
  _fd_recent_listing 7 "$all_results" "${recent_args[1]}" "${recent_args[2]:-.}" ''
}
alias fdlfwt=fd_latest_files_with_filetype

fd_latest_md_files(){
  fd_latest_files_with_filetype md "$@"
}
alias fdlmds=fd_latest_md_files

fd_latest_files_in_dir(){
  local all_results=0
  local -a recent_args
  _fd_recent_options "$@"
  if (( ${#recent_args} != 1 )); then
    printf 'Usage: fd_latest_files_in_dir [-a|--all] DIRECTORY\n' >&2
    return 2
  fi
  _fd_recent_listing 7 "$all_results" '' "${recent_args[1]}" ''
}

fd_find_with_ending(){
  if (( $# == 0 )); then
    printf 'Usage: fd_find_with_ending [FD_OPTION...] EXTENSION\n' >&2
    return 2
  fi
  local ending="${@[-1]}"
  fdfind "${@[1,-2]}" -tf -e "$ending"
}

fd_latest_file_in_dir(){
  local all_results=0 found file_entry
  local -a recent_args files
  _fd_recent_options "$@"
  if (( ${#recent_args} < 1 || ${#recent_args} > 2 )); then
    printf 'Usage: fd_latest_file_in_dir [-a|--all] DIRECTORY [EXCLUDE_REGEX]\n' >&2
    return 2
  fi
  found=$(_fd_recent_files 1 "$all_results" '' "${recent_args[1]}" "${recent_args[2]:-}") || return
  [[ -n $found ]] || return 0
  files=("${(@0)found}")
  for file_entry in "${files[@]}"; do
    [[ -z $file_entry ]] || printf '%s\n' "$file_entry"
  done
}
alias fdlfid=fd_latest_file_in_dir
alias fdlfsid=fd_latest_files_in_dir
function fdlfidc() {
  if (( $# != 1 )); then
    print -u2 'Usage: fdlfidc DIRECTORY'
    return 2
  fi
  local latest_file
  latest_file=$(fd_latest_file_in_dir "$1") || return
  [[ -n $latest_file ]] || return 1
  print -r -- "$latest_file" | setclip -p
}
function fdlfidx() {
  if (( $# < 2 )) || [[ -z "$1" || -z "$2" ]]; then
    printf '%s\n' 'Usage: fdlfidx DIRECTORY COMMAND [ARG...]' >&2
    return 2
  fi
  local dir_to_search="$1"
  shift
  local cmd_to_execute="$1"
  shift
  local latest_file mime_type
  latest_file=$(fd_latest_file_in_dir "$dir_to_search") || return
  if [[ -z "$latest_file" ]]; then
    printf 'No file found in: %s\n' "$dir_to_search" >&2
    return 1
  fi
  if [[ ! -f "$latest_file" || ! -r "$latest_file" ]]; then
    printf 'Not a readable regular file: %s\n' "$latest_file" >&2
    return 1
  fi
  printf '%s\n' "$latest_file" || return

  case "${cmd_to_execute:t}" in
    cat|bat|batcat|glow|tail|head|less|more)
      if ! command -v file >/dev/null 2>&1; then
        printf '%s\n' 'The file command is required to check for binary files.' >&2
        return 1
      fi
      mime_type=$(file --brief --dereference --mime-type -- "$latest_file") || return
      case "$mime_type" in
        text/*|application/json|application/*+json|application/xml|application/*+xml|application/javascript|application/x-javascript|image/svg+xml|inode/x-empty|application/x-empty) ;;
        *)
          printf 'Refusing to display a non-text file: %s (%s)\n' "$latest_file" "$mime_type" >&2
          return 1
          ;;
      esac
      ;;
  esac

  "$cmd_to_execute" "$latest_file" "$@"
}

# Clear aliases retained by shells that loaded the earlier definitions.
unalias fdlfidxcat fdlfidxbat fdlfidxgat fdlfidxt 2>/dev/null || true

function fdlfidxcat(){
  fdlfidx "${1:-}" cat "${@:2}"
}
function fdlfidxbat(){
  local bat_command=bat
  if command -v batcat >/dev/null 2>&1; then
    bat_command=batcat
  fi
  fdlfidx "${1:-}" "$bat_command" "${@:2}"
}
function fdlfidxgat(){
  fdlfidx "${1:-}" glow "${@:2}"
}
function fdlfidxt(){
  fdlfidx "${1:-}" tail -f "${@:2}"
}

fd_latest_files_by_git_date_with_filetype() {
  local all_results=0 file_type limit found file_entry metadata record
  local -a recent_args files records git_opts
  _fd_recent_options "$@"
  if (( ${#recent_args} < 1 || ${#recent_args} > 2 )); then
    printf 'Usage: fd_latest_files_by_git_date_with_filetype [-a|--all] FILETYPE [LIMIT]\n' >&2
    return 2
  fi
  file_type=${recent_args[1]}
  limit=${recent_args[2]:-7}
  if [[ $limit != <1-> ]]; then
    printf 'LIMIT must be a positive integer.\n' >&2
    return 2
  fi
  (( limit <= 7 )) || limit=7
  (( all_results )) || git_opts+=(--since-as-filter='7 days ago')
  found=$(git ls-files -z -- "*.$file_type") || return
  [[ -n $found ]] || return 0
  files=("${(@0)found}")
  for file_entry in "${files[@]}"; do
    [[ -f $file_entry ]] || continue
    metadata=$(git --literal-pathspecs log -1 "${git_opts[@]}" --format='%ct:%aI|%an|%s' -- "$file_entry") || return
    [[ -n $metadata ]] || continue
    records+=("$metadata|$file_entry")
  done
  records=("${(@On)records}")
  if (( ! all_results && ${#records} > limit )); then
    records=("${(@)records[1,limit]}")
  fi
  (( ${#records} )) || return 0
  setopt local_options pipefail
  for record in "${records[@]}"; do
    printf '%s\n' "${record#*:}"
  done | column -t -s '|' -o ' | ' -T 3 -N 'Date','Author','Message','File' | sed_bold_firstrow
}

find_file_endings_unique(){
	local search_dir="${1:-.}"
	find "${search_dir}" -type f | cut -d '/' -f2- | grep -F '.' | rev | cut -d'.' -f1 | rev | sort | uniq
}

fd_images(){
	fdfind -e jpg -e jpeg -e png -e gif -e bmp -e tiff -e webp
}

fd_pdf(){
	fdfind -e pdf
}

fd_videos(){
	fdfind -e mp4 -e mkv -e webm -e avi -e mov -e flv -e wmv -e mpeg -e mpg -e 3gp -e mts
}

# Run fdfind like `fd [OPTION...] [PATTERN] [PATH...]`, limited to regular
# files whose name matches FILTER. A user pattern narrows the result through
# --and. A single positional argument that names a directory is a path.
_fd_filtered_search() {
  local func_name=$1 filter=$2
  shift 2
  local arg pattern=. end_options=0 i
  local -a opts positionals paths
  while (( $# )); do
    arg=$1
    shift
    if (( end_options )) || [[ $arg != -?* ]]; then
      positionals+=("$arg")
      continue
    fi
    case $arg in
      --)
        end_options=1
        ;;
      -g|--glob|-F|--fixed-strings)
        printf '%s: %s is not supported; the file filter is a regex.\n' "$func_name" "$arg" >&2
        return 2
        ;;
      -x|--exec|-X|--exec-batch)
        # The command runs until a literal ';' or the end of the arguments.
        opts+=("$arg")
        while (( $# )); do
          opts+=("$1")
          shift
          [[ ${opts[-1]} != ';' ]] || break
        done
        ;;
      --and|-d|--max-depth|--min-depth|--exact-depth|-E|--exclude|-t|--type|\
      -e|--extension|-S|--size|--changed-within|--change-newer-than|--newer|\
      --changed-after|--changed-before|--change-older-than|--older|-o|--owner|\
      --format|--batch-size|--ignore-file|-c|--color|-j|--threads|\
      --max-results|--base-directory|--path-separator|--search-path)
        if (( ! $# )); then
          printf '%s: %s needs a value.\n' "$func_name" "$arg" >&2
          return 2
        fi
        opts+=("$arg" "$1")
        shift
        ;;
      --*)
        opts+=("$arg")
        ;;
      *)
        # Short option cluster such as -HI or -Hd2.
        opts+=("$arg")
        for (( i = 2; i <= ${#arg}; i++ )); do
          case ${arg[i]} in
            g|F)
              printf '%s: -%s is not supported; the file filter is a regex.\n' "$func_name" "${arg[i]}" >&2
              return 2
              ;;
            d|E|t|e|S|o|c|j)
              if (( i == ${#arg} )); then
                if (( ! $# )); then
                  printf '%s: -%s needs a value.\n' "$func_name" "${arg[i]}" >&2
                  return 2
                fi
                opts+=("$1")
                shift
              fi
              break
              ;;
          esac
        done
        ;;
    esac
  done

  if (( ${#positionals} == 1 )) && [[ -d ${positionals[1]} ]]; then
    paths=("${positionals[1]}")
  elif (( ${#positionals} )); then
    pattern=${positionals[1]}
    paths=("${(@)positionals[2,-1]}")
  fi

  setopt local_options pipefail
  fdfind "${opts[@]}" -tf --and "$filter" -- "$pattern" "${paths[@]}" | sort
}

fd_shell_scripts() {
  _fd_filtered_search fd_shell_scripts '.*\.[a-z]?sh$' "$@"
}
fd_sh(){
  fd_shell_scripts "$@"
}
fd_sh.(){
  fd_shell_scripts -HI "$@"
}

fd_shell_script_file_access_flags(){
	fdfind "$@" '.*\.sh$' | sort | xargs -I{} stat "{}" | grep -e File -e Access | grep -F -e '(' -e File | trim | awk 'NR%2==1 {file=$2} NR%2==0 {print file, $2, $3}' | sed 's/ Uid://g'
}

fd_shell_scripts_without_execution_rights(){
	fd_shell_script_file_access_flags "$@" | grep -v 7
}

fd_fix_shell_scripts_without_execution_rights(){
	fd_shell_scripts_without_execution_rights "$@" | awk '{print $1}' | xargs -I{} chmod 755 "{}"
}

fd_markdown_docs() {
  _fd_filtered_search fd_markdown_docs '.*\.[a-z]?md$' "$@"
}
fd_md(){
  fd_markdown_docs "$@"
}

fd_md.(){
  fd_markdown_docs -HI "$@"
}

fd_dirs_with_search_term(){
	local search_term="${1}"
	fdfind "${search_term}" | xargs -I{} dirname "{}" | sort | uniq
}

fd_executables_in_path() {
  # Split PATH into array by :
  local -a path_dirs
  IFS=: read -rA path_dirs <<< "$PATH"

  # Iterate over each directory
  for dir in "${path_dirs[@]}"; do
    [[ -d $dir ]] || continue   # skip if not a directory

    # Find only regular executable files (not directories)
    find "$dir" -maxdepth 1 -type f -perm -u+x -printf "%f\n" 2>/dev/null
  done | sort -u
}

find_all_executables_in_bin_dirs(){
	fdfind -p '.*/bin/.*' --type=executable /
}

find_configuration_files(){
	local dirpath="${1:-.}"
	fdfind -H -tf '.*\.yml$|.*\.yaml$|.*\.properties$|.*\.conf$|.*\.cfg.xml$|.*\.ini$|.*\.env$' "${dirpath}"
}

find_all_file_types(){
  fdfind | rev | cut -d '.' -f1 | rev | sort | uniq | grep -v '/'
}

find_files_from_given_day_and_create_symlink_collection(){
  if (( $# != 5 )) || [[ $1 != <1-> || $2 != <1-> ]] || (( $1 > $2 )); then
    printf 'Usage: find_files_from_given_day_and_create_symlink_collection START_YEAR END_YEAR MM-DD MM-DD TARGET_DIRECTORY\n' >&2
    return 2
  fi
  local start_year=$1 end_year=$2 search_start=$3 search_end=$4 target_dir=$5
  local y found src
  local -a files
  [[ -d $target_dir ]] || { printf 'Missing target directory: %s\n' "$target_dir" >&2; return 1; }
  for (( y=start_year; y<=end_year; y++ )); do
    found=$(fdfind -0 -t f --changed-after "$y-$search_start" --changed-before "$y-$search_end") || return
    [[ -n $found ]] || continue
    files=("${(@0)found}")
    for src in "${files[@]}"; do
      [[ -z $src ]] && continue
      if [[ -e "$target_dir/${src:t}" || -L "$target_dir/${src:t}" ]]; then
        printf 'Target already exists: %s\n' "$target_dir/${src:t}" >&2
        return 1
      fi
      ln -s -- "${src:A}" "$target_dir/${src:t}" || return
    done
  done
}

#fdfind with ending
fdwe(){
  fdfind ".*\.${1}$"
}


# 1) Find regular files without an extension (no dot in basename), ignoring dotfiles
fd_files_with_no_ending() {
  # Matches basenames with no dot; fdfind matches against basename by default (no --full-path)
  fdfind --type f --exclude '.*' -0 '^[^.]+$' "${1:-.}"
}

fd_find_camelcase_files() {
  local file_ending
  if [[ -z "$1" ]]; then
    file_ending='(?:\..*)?'
  else
    file_ending="\\.${1}"
  fi

  local fd_search_pattern="^(?:[a-z]+[A-Z][a-z0-9]*)+${file_ending}$"
  /usr/bin/fdfind -I -tf "${fd_search_pattern}"
}

find_jar(){
    local search_term="${1}"
    local search_root="${2:-.}"
    fd -HI "${search_term}.*\.jar$" "$search_root" | head -n1
}

fd_env_type_files(){
  fd -HI '^.env'
}

fd_dotenv(){
  fd -HI '^.env$'
}

fd_latest_handoff_docs(){
  fd handoff -td -d4 -0 | xargs -0 -I{} zsh -c 'print -r -- "${1%/}"/*(D.om[1])' _ '{}' | xargs ls -l | sort -k6
}
alias flhd=fd_latest_handoff_docs
