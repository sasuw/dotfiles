rg_show_only_matches_uniq_sorted(){
	local filename="${1}"
	local search_term="${2}"
	#-oIN=match only, no filename, no line numbers
	rg --glob "${filename}" -oIN "${search_term}" | awk NF | sort | uniq
}

#find file with rg and open it with batcat
rgb(){
	local search_term="${1}"
	rg -. -l --sort=path "${1}" | xargs -I{} batcat "{}"
}

rgv() {
  local cmd="cat"
  for pattern in "$@"; do
    cmd+=" | rg -v ${(q)pattern}"
  done
  eval "$cmd"
}

rge() {
  local -a args
  for pattern in "$@"; do
    args+=(-e "$pattern")
  done
  rg "${args[@]}"
}

rga() {
  (( $# )) || return 0

  local colorflag
  [[ -t 1 ]] && colorflag="--color=always" || colorflag="--color=never"

  local cmd="rg $colorflag -- $1"
  shift

  local p
  for p in "$@"; do
    cmd+=" | rg $colorflag -- $p"
  done

  eval "$cmd"
}

find_configuration_files0() {
  local dirpath="${1:=.}"
  fdfind -H -tf -0 '.*\.yml$|.*\.yaml$|.*\.properties$|.*\.conf$|.*\.cfg\.xml$|.*\.ini$|.*\.env$' "$dirpath"
}

rg_conf_files() {
  emulate -L zsh
  setopt localoptions pipefail

  if (( $# < 1 )); then
    print -u2 "usage: search_configuration_files <pattern> [dir=. ] [rg options...]"
    return 2
  fi

  local pattern="$1"; shift
  local dirpath="."
  if (( $# )); then
    # If the next arg looks like a directory, treat it as dirpath; otherwise leave '.'.
    if [[ -d "$1" ]]; then
      dirpath="$1"
      shift
    fi
  fi

  # Capture paths into an array (newline-split) to preserve spaces in filenames
  local -a files
  files=("${(@f)$(find_configuration_files "$dirpath")}")

  if (( ${#files} == 0 )); then
    print -u2 "No configuration files under: $dirpath"
    return 1
  fi

  # Use -e for pattern, then -- to end options, then file list
  rg "$@" -e "$pattern" -- "${files[@]}"
}

function rgmds(){
  emulate -L zsh
  setopt pipefail
  if (( $# == 0 )); then
    print -u2 'Usage: rgmds PATTERN [RG_OPTIONS...]'
    return 2
  fi
  local search_term="${1}"
  shift
  # The shell guard avoids an empty-input rg call without GNU xargs -r.
  fdfind -0 '\.md$' -tf | xargs -0 sh -c '
    min_args=$1; shift
    [ "$#" -gt "$min_args" ] || exit 0
    exec rg -HS "$@"
  ' sh "$(( $# + 2 ))" "$@" -- "$search_term"
}

function rglmd(){
  if (( $# == 0 )); then
    print -u2 'Usage: rglmd PATTERN [RG_OPTIONS...]'
    return 2
  fi
  local search_term="$1"
  shift
  rgmds "$search_term" -l "$@"
}

function rgenv(){
  emulate -L zsh
  setopt pipefail
  if (( $# == 0 )); then
    print -u2 'Usage: rgenv PATTERN [RG_OPTIONS...]'
    return 2
  fi
  local search_term="$1"
  shift
  # The shell guard avoids an empty-input rg call without GNU xargs -r.
  fdfind -0 -HI '\.env(\..*)?$' -tf | xargs -0 sh -c '
    min_args=$1; shift
    [ "$#" -gt "$min_args" ] || exit 0
    exec rg -HS "$@"
  ' sh "$(( $# + 2 ))" "$@" -- "$search_term"
}

function rglenv(){
  if (( $# == 0 )); then
    print -u2 'Usage: rglenv PATTERN [RG_OPTIONS...]'
    return 2
  fi
  local search_term="$1"
  shift
  rgenv "$search_term" -l "$@"
}
