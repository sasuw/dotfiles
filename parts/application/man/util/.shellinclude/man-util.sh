#!/usr/bin/env zsh
function man_find_options_for_cmd(){
  local cmdname="${1}"
  man "$cmdname" | grep -A1 -E '^\s+\-'
}

man_grep_cmd_options () {
	local cmdname="$1" 
	local grep_param="$2"

	# Only match lines that start with an option definition (short or long)
	# and include the requested pattern (e.g. -n, --help, etc.)
	man "$cmdname" | grep -A1 -E "^\s+-.*${grep_param}"
}

#Find command options with given text, e.g. 
#`man_grep_cmd_options_with_option_name sed buffer` outputs
#-u, --unbuffered
man_grep_cmd_options_with_option_name () {
	local cmdname="$1" 
	local grep_param="$2"

	# Only match lines that start with an option definition (short or long)
	# and include the requested pattern (e.g. -n, --help, etc.)
	man "$cmdname" | grep -A1 -E "^\s+-${grep_param}(,|\s)"
}

#Prints command options like you execute them
#E.g. to find out what `ls -lrht` does execute
#man_print_cmd_options ls lrht
function man_print_cmd_options() {
  local cmdname="$1"
  shift
  local requested_options="$*"
  local spaced_out_options="$requested_options"

  # Check if the full options string is directly present
  local man_content
  man_content=$(man_find_options_for_cmd "$cmdname")
  echo "$man_content" | grep -F -- "$requested_options" > /dev/null 2>&1
  local last_cmd_return_code=$?

  # If it's a single argument and didn't match, split it up
  if [[ $last_cmd_return_code -ne 0 && $# == 1 ]]; then
    spaced_out_options="${(j: :)${(s::)requested_options}}"
  fi

  # Loop over each pattern and grep it separately, preserving order
  local pattern_string
  for pattern in ${(z)spaced_out_options}; do
    pattern_string="${pattern}"
    man_grep_cmd_options_with_option_name "${cmdname}" "${pattern_string}" | awk NF
  done
}


