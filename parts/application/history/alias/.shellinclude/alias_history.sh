#!/usr/bin/env zsh

### Search history, when multiple terms given they are combined with AND
h0g_and() {
  local out
  out=$(history 0 \
    | rg -v 'h0g ' \
    | rg -v 'hgg ' \
    | rg '^[[:space:]]*[0-9]+[[:space:]]+') || return

  local term
  for term in "$@"; do
    out=$(print -r -- "$out" | rg -iF -- "$term") || return
  done

  print -r -- "$out"
}

function h0g_or(){
    local grep_args=""
    for term in "$@"; do
        grep_args="$grep_args -e \"$term\""
    done
    history 0 | rg -v 'h0g ' | rg -v 'hgg ' | eval "rg -i '[0-9]{1,}[[:space:]]+.*?''$grep_args'"
}
#hgg: history grep (the extra g is there to avoid confusion with version management tool HG, aka. Mercury)
alias hgg='h0g_and' #with multiple params and is the default behaviour
alias hggo='h0g_or'

#history cmd
#finds commands executed with a program. E.g. "hcmd git" lists "git show (...)", "git add ." etc.
function hcmd(){
    local progname="$1"
    history 0 | cut -d ' ' -f3- | grep -i "^${progname} " | sort | uniq
}

#history cmd, no arguments
function hcmdna(){
    local progname="$1"
    local amount_of_arguments="${2:-2}"
    hcmd "${progname}" | cut -d ' ' -f1-$amount_of_arguments | sort | uniq
}


alias h="history"

alias h0a="history 0"

alias h0t='history 0 | tail -n'

alias h9="history -9"

function hn(){
    local history_start_entry="$1"
    local history_amount_of_entries="${2:-30}"
    history $history_start_entry | head -n "$history_amount_of_entries"
}

function hnl(){
    local history_start_entry="$1"
    history $history_start_entry | less
}

#Finds commands executed containing somewhere the given string
function history_grep_cmd(){
    local cmd_name="${1}"
    history 0 | grep -E '^[0-9]{1,6}  '"${cmd_name}" | cut -d ' ' -f3- | sort | uniq
}

hist_context() {
  local term="$1"
  local ctx="${2:-2}"

  if [[ -z "$term" ]]; then
    echo "Usage: hist_context <search_term> [number_of_context_lines]"
    echo "Example: hist_context 'git commit' 3"
    return 1
  fi

  # Get numbered history and search it with context in a single stream.
  # Prefer ripgrep if available (faster), else fall back to grep.
  if command -v rg >/dev/null 2>&1; then
    fc -l 1 | rg -F -C "$ctx" -- "$term" \
      | awk -v pat="$term" '
          $0=="--" { print "    ..."; next }
          { if (index($0, pat)) printf ">>> %s <<<\n", $0; else printf "    %s\n", $0 }'
  else
    fc -l 1 | grep -F -C "$ctx" -- "$term" \
      | awk -v pat="$term" '
          $0=="--" { print "    ..."; next }
          { if (index($0, pat)) printf ">>> %s <<<\n", $0; else printf "    %s\n", $0 }'
  fi
}

alias hog='cat $HOME/.zsh_history_bak/zsh_history_2024_06_06.bak | cut -d ";" -f 2 | grep -i '
