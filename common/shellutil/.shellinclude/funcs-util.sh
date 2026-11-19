function find_bin_in_common_dirs_with_ls(){
	#e.g. for redhat/ubi9-minimal image
	ls -l /bin /usr/bin/ /usr/sbin/ /opt/ /sbin/ | grep '^-' | awk '{print $NF}' | sort | uniq
}

limit_lines() {
  local n=$1
  local file=$2
  if [[ -z "$n" || -z "$file" ]]; then
    echo "Usage: limit_lines <n> <file>"
    return 1
  fi
  fold -w "$n" -s -- "$file"
}

limit_lines_truncate() {
  local n=$1
  local file=$2
  if [[ -z "$n" || -z "$file" ]]; then
    echo "Usage: limit_lines_truncate <n> <file>"
    return 1
  fi
  cut -c -"${n}" -- "$file"
}

head_tail(){
	local head_limit=${1:-10}
	local tail_limit=${2:-$head_limit}
	#Could be written shorter like this: tee >(tail -n2) | head -n2
	#but the mechanism is a bit less clear that way
	tee >(head -n $head_limit) >(tail -n $tail_limit) | cat > /dev/null
}

#Compare man pages over ssh
function mancomp_ssh(){
    local executor="${3:-sdiff}"
    "$executor" <(man $1) <(ssh $2 "man $1 | col -bx")
}

function oneline(){
	head $1 | tail -n1
}

function stat_oneline(){
	stat $1 | grep -e Gid -e File | sed 'N;s/\n/ /' | sed -E 's/([a-zA-Z]+):/\| \1:/g' | cut -d ' ' -f4- | tr -s ' '
}

function xax(){
	xargs -I{} $1 "{}"
}

##
# Copies the absolute path of the given string if it's a filepath and puts it on the clipboard in single quotes
##
copy_path() {
    local input
    input=${1:-$(</dev/stdin)}
    realpath "$input" | sed "s/.*/'&'/" | setclip
}

function execute_in_subdirs(){
    local function_to_execute="$1"
    local current_dir="$PWD"

    # Check if a function name was provided
    if [ -z "$function_to_execute" ]; then
        echo "Error: Please provide a function name to execute."
        return 1
    fi

    # Check if the provided function exists
    if ! declare -F "$function_to_execute" > /dev/null; then
        echo "Error: Function '$function_to_execute' does not exist."
        return 1
    fi

    # Iterate through all subdirectories
    for dir in */; do
        if [ -d "$dir" ]; then
            echo "Entering directory: $dir"
            cd "$dir"

            # Execute the provided function
            "$function_to_execute"

            # Return to the parent directory
            cd "$current_dir"
        fi
    done
}

function kill_application_at_port(){
    local port=$1
    local port_output_file="/tmp/ss-output-port$port.txt"
    sudo ss -lptn "sport = :${port}" | cut -d '=' -f2 | tail -n1 | cut -d ',' -f1 > "${port_output_file}"
    if [[ $(sudo ss -lptn "sport = :${port}" | wc -l ) -eq 1 ]]
    then
        echo "There is no application running on port $port"
        return 0
    fi
    cat "${port_output_file}" | xargs kill -9
    echo "Killed process running on port $port"
}

function sortmtime() {
  emulate -L zsh
  setopt pipefail
  local sort_order='-k1,1nr'
  case "${1:-}" in
    -h|--help)
      print -r -- 'Usage: sortmtime [-a|--ascending] < FILE_LIST'
      return 0
      ;;
    -a|--ascending) sort_order='-k1,1n'; shift ;;
  esac
  if (( $# )); then
    print -u2 -r -- 'Usage: sortmtime [-a|--ascending] < FILE_LIST'
    return 2
  fi

  local file
  while IFS= read -r file || [[ -n "$file" ]]; do
    stat --printf='%Y\t%y\t%n\n' -- "$file" || return
  done |
    sort "$sort_order" |
    cut -f2-
}