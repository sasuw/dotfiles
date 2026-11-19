#!/usr/bin/env zsh
#Run by interactive shells (see https://zsh.sourceforge.io/Doc/Release/Files.html)
logger "ZDOT .zshrc started" 2>/dev/null || true

. "$HOME/.bin/common.sh" #now we can use function source_all_sh_files_in_subdir_of_home
source_localenv_interactive_files

# Optional personal settings load before prompt and generic snippets.
[[ ! -r "$HOME/.shellinclude/01-personal-env.sh" ]] || source "$HOME/.shellinclude/01-personal-env.sh"

# Lines configured by zsh-newuser-install
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000

# Custom history options
setopt HIST_IGNORE_SPACE
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_VERIFY               # Do not execute immediately upon history expansion.
setopt APPEND_HISTORY            # append to history file

unsetopt beep
bindkey -e
# Show pasted text like typed text; zsh highlights it as standout by default.
zle_highlight+=(paste:none)

zstyle :compinstall filename '${ZDOTDIR:-$HOME}/.zshrc'

setopt interactivecomments
setopt prompt_subst
zmodload zsh/datetime 2>/dev/null

prompt_show_git_branch() {
  local branch git_status status_line xy
  local staged_count=0
  local unstaged_count=0
  local untracked_count=0
  local conflict_count=0
  local ahead_count=0
  local behind_count=0

  if command git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null)
    if [[ -n "$branch" ]]; then
      while IFS= read -r status_line; do
        case "$status_line" in
          "# branch.ab "*)
            ahead_count=${${(z)status_line}[3]#+}
            behind_count=${${(z)status_line}[4]#-}
            ;;
          "1 "*|"2 "*)
            xy=${status_line:2:2}
            [[ ${xy:0:1} != "." ]] && ((staged_count++))
            [[ ${xy:1:1} != "." ]] && ((unstaged_count++))
            ;;
          "u "*)
            ((conflict_count++))
            ;;
          "? "*)
            ((untracked_count++))
            ;;
        esac
      done < <(git status --porcelain=v2 --branch 2>/dev/null)

      ((staged_count > 0)) && git_status="${git_status} +${staged_count}"
      ((unstaged_count > 0)) && git_status="${git_status} ~${unstaged_count}"
      ((untracked_count > 0)) && git_status="${git_status} ?${untracked_count}"
      ((conflict_count > 0)) && git_status="${git_status} !${conflict_count}"
      ((ahead_count > 0)) && git_status="${git_status} ^${ahead_count}"
      ((behind_count > 0)) && git_status="${git_status} v${behind_count}"

      if [[ ${#branch} -gt 15 ]]; then
        branch="${branch:0:15}…"
      fi
      echo "%F{cyan}(${branch}${git_status})%f$PROMPT_SEPARATOR"
    fi
  fi
}

prompthelp() {
  echo "+N staged, ~N unstaged, ?N untracked, !N conflicts, ^N unpushed commits, vN behind upstream"
}


prompt_init_spacing() {
  # Unicode conversions abort startup in the C locale. Keep plain spacing
  # unless the active character set supports the prompt's Unicode spaces.
  UNICODE_THIN_SPACE=' '
  UNICODE_HAIR_SPACE=' '
  if zmodload zsh/langinfo && [[ ${langinfo[CODESET]} == UTF-8 ]]; then
    printf -v UNICODE_THIN_SPACE \\U2009
    printf -v UNICODE_HAIR_SPACE \\U200A
  fi
  NO_SPACE=''
  PROMPT_SPACE=$UNICODE_HAIR_SPACE
}
prompt_init_spacing
PROMPT_SEPARATOR="%B$PROMPT_SPACE|$PROMPT_SPACE%b"
PROMPT_TIMER_SHOW=0us

prompt_timer_now_us() {
  local seconds micros

  if [[ -n ${EPOCHREALTIME:-} ]]; then
    seconds=${EPOCHREALTIME%.*}
    micros=${EPOCHREALTIME#*.}
    micros="${micros}000000"
    REPLY="${seconds}${micros:0:6}"
  else
    REPLY=$(date +%s%6N)
  fi
}

prompt_timer_format_us() {
  local delta_us=$1
  local us=$((delta_us % 1000))
  local ms=$(((delta_us / 1000) % 1000))
  local s=$(((delta_us / 1000000) % 60))
  local m=$(((delta_us / 60000000) % 60))
  local h=$((delta_us / 3600000000))

  if (( h > 0 )); then
    PROMPT_TIMER_SHOW=${h}h${m}m
  elif (( m > 0 )); then
    PROMPT_TIMER_SHOW=${m}m${s}s
  elif (( s >= 10 )); then
    PROMPT_TIMER_SHOW=${s}.$((ms / 100))s
  elif (( s > 0 )); then
    PROMPT_TIMER_SHOW=${s}.$(printf %03d "$ms")s
  elif (( ms >= 100 )); then
    PROMPT_TIMER_SHOW=${ms}ms
  elif (( ms > 0 )); then
    PROMPT_TIMER_SHOW=${ms}.$((us / 100))ms
  else
    PROMPT_TIMER_SHOW=${us}us
  fi
}

prompt_timer_preexec() {
  prompt_timer_now_us
  PROMPT_TIMER_STARTED_AT_US=$REPLY
  PROMPT_TIMER_COMMAND_ACTIVE=1
}

prompt_timer_precmd() {
  local delta_us

  if [[ ${PROMPT_TIMER_COMMAND_ACTIVE:-0} -ne 1 ]] || [[ -z ${PROMPT_TIMER_STARTED_AT_US:-} ]]; then
    PROMPT_TIMER_SHOW=${PROMPT_TIMER_SHOW:-0us}
    return
  fi

  prompt_timer_now_us
  delta_us=$((REPLY - PROMPT_TIMER_STARTED_AT_US))
  prompt_timer_format_us "$delta_us"
  unset PROMPT_TIMER_STARTED_AT_US
  PROMPT_TIMER_COMMAND_ACTIVE=0
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec prompt_timer_preexec
add-zsh-hook precmd prompt_timer_precmd

# Host color: client machines get warm colors, servers cool ones, so a glance
# at the prompt tells the two apart. Within a group the hostname is hashed to
# pick one of the group's colors, so similar machines still differ.
#
# Only base16-mapped color names are used: they follow the active terminal
# theme and stay readable on light and dark backgrounds, unlike numeric
# 256-color codes.
#
# The class comes from rules/machine_class, called directly: .shellinclude is
# sourced further below, after the prompt is already built, so a part-exported
# value would only take effect in nested shells. Presetting MACHINE_CLASS
# (e.g. in .zshvars) overrides the rule and skips the call. The rule is
# optional: without it, a fresh generic setup falls back to the client class.
#
# Palette entries are "colour" or "colour:bold". Bold doubles the number of
# distinct looks per group without leaving the base16-mapped colour names.
PROMPT_CLIENT_COLORS=(yellow magenta red yellow:bold magenta:bold red:bold)
PROMPT_SERVER_COLORS=(blue cyan green blue:bold cyan:bold green:bold)

prompt_machine_class() {
  local rule="${DOTFILE_DIR:-$HOME/dotfiles}/rules/machine_class"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/machine_class"

  # Preset value wins, then the cache, and only then the rule itself: the
  # rule forks a subshell, and this runs on every shell startup.
  if [[ -n ${MACHINE_CLASS:-} ]]; then
    REPLY=$MACHINE_CLASS
    return
  fi

  # Cache is keyed by hostname so it self-invalidates if the machine is
  # renamed or $HOME is shared between hosts.
  if [[ -r $cache ]]; then
    local cached_host cached_class
    IFS=: read -r cached_host cached_class < "$cache"
    if [[ $cached_host == ${HOST%%.*} && -n $cached_class ]]; then
      REPLY=$cached_class
      return
    fi
  fi

  if [[ -x $rule ]]; then
    REPLY=$("$rule" 2>/dev/null) || REPLY=client
  else
    REPLY=client
  fi
  [[ -n $REPLY ]] || REPLY=client

  # Caching is best effort: a read-only or unwritable $HOME must not print
  # anything on every shell start. The redirection itself can fail, so the
  # whole write runs in a subshell with stderr silenced.
  ( mkdir -p "${cache:h}" && print -r -- "${HOST%%.*}:$REPLY" > "$cache" ) 2>/dev/null
}

prompt_host_color() {
  local host=${1:-$HOST}
  local -a palette
  local char hash class

  # Only resolve the class when the caller did not pass one at all; an
  # explicitly empty second argument means "unknown" and takes the default.
  if (( $# >= 2 )); then
    class=$2
  else
    prompt_machine_class
    class=$REPLY
  fi

  case $class in
    client) palette=($PROMPT_CLIENT_COLORS) ;;
    server) palette=($PROMPT_SERVER_COLORS) ;;
    *)      REPLY=yellow; REPLY2=; return ;;
  esac

  # Strip the domain part so short and qualified hostnames agree.
  host=${host%%.*}

  # FNV-1a: the hostnames in use are short and share long prefixes
  # (for example server1/server6/server8), which a weaker hash can group.
  hash=2166136261
  for char in ${(s::)host}; do
    (( hash = (hash ^ #char) * 16777619 % 4294967296 ))
  done

  # zsh arrays are 1-based. REPLY is the colour name; REPLY2 is %B when the
  # chosen slot is a bold variant, so callers can wrap the segment in %B/%b.
  local slot=${palette[$((hash % $#palette + 1))]}
  REPLY=${slot%%:*}
  [[ $slot == *:bold ]] && REPLY2=%B || REPLY2=
}

prompt_host_color
PROMPT_HOST_COLOR=${PROMPT_HOST_COLOR:-$REPLY}
PROMPT_HOST_BOLD=${PROMPT_HOST_BOLD-$REPLY2}
unset REPLY REPLY2

PROMPT="%F{magenta}%?%F{white}$PROMPT_SEPARATOR%F{yellow}\${PROMPT_TIMER_SHOW:-0us}%F{white}$PROMPT_SEPARATOR%F{green}%n@${PROMPT_HOST_BOLD}%F{$PROMPT_HOST_COLOR}%m%b%F{white}$PROMPT_SEPARATOR\$(prompt_show_git_branch)%F{blue}%1~ %F{reset_color}$ "

export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/.local/bin #ansible
export PATH=$PATH:$HOME/bin

#export EDITOR="/usr/bin/vi"
export EDITOR=vim
export VISUAL=vim


DISABLE_AUTO_TITLE="true"
precmd () {print -Pn "\e]0;%n@%m: %~\a"}

#apparently modern go should not have these (commented out on 3.8.2023)
#export GOPATH=$HOME/Applications/go/bin
#export GOROOT=$HOME/Applications/go


#TODO END

get_nth_line() {
    if [ $# -ne 2 ]; then
        echo "Usage: get_nth_line <n> <input>"
        return 1
    fi

    local n="$1"
    local input="$2"

    if ! [[ $n =~ ^[0-9]+$ ]]; then
        echo "Error: The first argument (n) must be a non-negative integer."
        return 1
    fi

    if ! [ -n "$input" ]; then
        echo "Error: The second argument (input) is empty."
        return 1
    fi

    # Use tail to skip the first n-1 lines and then head to get the nth line
    echo "$input" | tail -n +$((n)) | head -1
}

##Prints nth line
nth() {
  local n=$1
  if [[ ! "$n" =~ '^[0-9]+$' ]]; then
    echo "Usage: nth <line-number>" >&2
    return 1
  fi
  sed -n "${n}p"
}

nth2() {
  nth 2
}

1st() {
  nth 1
}
alias first='1st'
lastline() {
  tail -n1
}

##Prints last nth line
nthl() {
  local n=$1
  tail -n "${n}" | head -n1
}

nim_find_public_procs() {
    grep -Iir "proc\s.*\*" src/ | awk 'BEGIN { FS = ":" } ; { print $2, $3 } ' | grep '^proc' | tr -s " " | sort
}

find_illegal_ex_fat_file_names() {
    find . -type f | while read -r file; do
        if echo "$file" | grep -q -E "[\:\|]"; then
            echo -n "$file contains illegal characters: "
            echo "$file" | grep -o -E "[\:\|]" | tr '\n' ' ' | sed 's/ $/\n/'
        fi
    done
}

export TIME_STYLE=long-iso

ls_newest_file_of_file_type(){
  local filetype=$1
  if [[ $filetype == '*' ]]; then
    local nameToSearch="*"
  else
    local nameToSearch="*.${filetype}"
  fi
  find . -maxdepth 1 -type f -name "${nameToSearch}" -type f -print0 | xargs -0 stat --format="%Y %n" | sort -nr | cut -d' ' -f2- | head -n1
}

ls_newest_file(){
  ls_newest_file_of_file_type '*'
}

remove_multiline_history() {
  # Backup the original history file just in case
  cp ~/.zsh_history ~/.zsh_history.bak

  # Remove lines that don't start with a ':' (which indicates the beginning of a new entry)
  awk '/^: [0-9]+:0;/{if (NR != 1) print buffer; buffer=$0; next} {buffer=buffer " " $0} END {print buffer}' ~/.zsh_history > ~/.zsh_history.cleaned

  # Replace the old history file with the cleaned version
  mv ~/.zsh_history.cleaned ~/.zsh_history

  # Reload zsh history
  fc -R ~/.zsh_history
}

#xdg-open newest file in directory
xon(){
  filetype=$1
  xdg-open $(ls_newest_file_of_file_type $filetype)
}

#xdg-open newest file in directory of [file type]
xof(){
  xdg-open $(ls_newest_file)
}

MANPATH="/usr/share/man:$MANPATH"

export PATH=/usr/local/swift/usr/bin:$PATH

#Source all files in .shellinclude
source_all_sh_files_in_subdir_of_home ".shellinclude"

#Remove duplicates from PATH
typeset -U PATH 
export PATH="$PATH:$HOME/perl5/bin"


subdir_exec(){
    if [[ -n $(find . -mindepth 1 -maxdepth 1 -type d -not -name '.*' -print -quit) ]]; then
        local cmd=$1
        for subdir in */
        do
            echo "Executing ${cmd} in ${subdir}"
            (cd "./$subdir" && eval "${cmd}")
            echo "----"
        done
    else
        echo "No non-hidden subdirectories found."
    fi
}

#######################################
# Returns lines found with given 2nd argument from any file found having string from 1st argument
# Arguments:
#   #1 file grep search string
#   #2 line grep search string
# Outputs:
#   Lines found from the files found
#######################################
function grep2x(){
    local filestr=$1
    local linestr=$2
    rg -l "${filestr}" | xargs -I"{}" grep -i "${linestr}" "{}"
}

function grep2x_java_no_tests(){
    local filestr=$1
    local linestr=$2
    rg -l --glob '*.java' --glob '!*Test*.java' "${filestr}" | xargs -I"{}" grep -i "${linestr}" "{}"
}

find_functions_with_keyword() {
  local keyword=$1
  local dir=${2:-.}  # Default to current directory
  local abs_dir=$(realpath "$dir")

  find "$abs_dir" -type f \( -name '*.zsh' -o -name '*.sh' \) | while read -r file; do
    awk -v kw="$keyword" -v file="$file" -v base="$abs_dir/" '
      /^[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*\{/ {
        in_func = 1
        func_name = $1
        sub(/\(\)\s*\{/, "", func_name)
        body = ""
        next
      }

      in_func {
        body = body $0 "\n"
        if ($0 ~ /\}/) {
          in_func = 0
          if (body ~ kw) {
            sub(base, "", file)
            print file ": " func_name
          }
        }
      }
    ' "$file"
  done
}


find_functions_with_keyword_in_dotfiles() {
  find_functions_with_keyword $1 "$DOTFILE_DIR"
}

alias vv='version -s'

function trim() {
    if [ $# -eq 0 ]; then
        # No argument provided, read from stdin
        sed 's/^\s*//;s/\s*$//'
    else
        # Argument provided, trim directly
        STRING_TO_TRIM=$1
        echo "$STRING_TO_TRIM" | sed 's/^\s*//;s/\s*$//'
    fi
}

#TODO get real device names/types from path like this: fd -p -td -d2 'pci|usb|thunderbolt' /sys/bus/ | grep 'devices' 
function get_pci_thunderbolt_usb_device_paths(){
  fd -p -td -d2 'pci|usb|thunderbolt' /sys/bus/ | grep 'devices' | xargs fd . | xargs readlink -f
}

function devices_list_runtime_status(){

  get_pci_thunderbolt_usb_device_paths | xargs -I"{}" fd -tf --print0 '^runtime_status$' "{}" | 
  awk -v RS='\0' '
    NF {
      path=$0
      line=""
      if ((getline line < path) > 0) {
        close(path)
        print path " | " line
      }
    }
  ' | rg --color=never -e usb -e pci -e thunderbolt
}

function devices_list_power(){
  get_pci_thunderbolt_usb_device_paths | xargs -I"{}" fd -tf --print0 '^control$' "{}" |
  awk -v RS='\0' '
    NF {
      path=$0
      line=""
      if ((getline line < path) > 0) {
        close(path)
        print path " | " line
      }
    }
  ' | grep -e usb -e pci -e thunderbolt
}


function devices_list_with_runtime_status(){
  local rtstatus="${1:-}"

  case "$rtstatus" in
    active|suspended|unsupported)
      ;;
    *)
      print -u2 "Usage: devices_list_with_status <active|suspended|unsupported>"
      return 2
      ;;
  esac
  echo "rtstatus: ${rtstatus}"
  devices_list_runtime_status | grep "| ${rtstatus}"
}


function dotfiles_add_config(){
  if (( $# < 2 || $# > 3 )) || [[ -z $1 || -z $2 ]]; then
    echo "Usage: dotfiles_add_config <base-directory> <directory-name> [config-name]"
    return 1
  fi
  local basedirpath="${1}"
  local dirname="${2}"
  local configname="${3:-default}"
  if [[ ! -d "$basedirpath" || "$dirname" == */* || "$configname" == */* ||
        "$dirname" == . || "$dirname" == .. || "$configname" == . || "$configname" == .. ]]; then
    echo "Invalid destination or configuration name" >&2
    return 1
  fi
  basedirpath="${basedirpath:A}"
  local newdir="${basedirpath}/${dirname}/${configname}/.shellinclude"
  if [[ "${newdir:A}" != "$basedirpath/"* ]]; then
    echo "Configuration resolves outside the selected directory" >&2
    return 1
  fi

  local filename
  if [[ $dirname == $configname ]]
  then
    filename="${configname}.sh"
  else
    filename="${configname}_${dirname}.sh"
  fi


  local newFilePath="${newdir}/${filename}"
  if [[ -e "$newFilePath" || -L "$newFilePath" ]]; then
    echo "Refusing to overwrite existing file: $newFilePath" >&2
    return 1
  fi

  mkdir -p "${newdir}" || return $?
  echo "#!/usr/bin/env zsh" > "${newFilePath}"
  echo "Added file ${newFilePath}"
}

function dotfiles_add_application_config(){
  if (( $# < 2 || $# > 3 )) || [[ -z $1 || -z $2 || ! -d $1 ]]; then
    echo "Usage: dotfiles_add_application_config <layer-root> <application-name> [config-name]"
    return 1
  fi

  local dotfiledir="${1:A}"
  local applicationdir="${dotfiledir}/parts/application"
  if [[ "${applicationdir:A}" != "$dotfiledir/"* ]]; then
    echo "Application directory resolves outside the selected layer" >&2
    return 1
  fi

  local dirname="${2}"
  local configname="${3:-default}"
  dotfiles_add_config "${applicationdir}" "${dirname}" "${configname}"
}

export PATH="$HOME/.bin:$PATH"

# Find the Homebrew prefix
# Why is the path needed here? It is set already in non-interactive files
if [[ -d "/home/linuxbrew/.linuxbrew" ]]
then
  for brew_path in /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin; do
    PATH=":${PATH}:"
    PATH="${PATH//:${brew_path}:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"
    PATH="${PATH:+$PATH:}${brew_path}"
  done
  export PATH

  HOMEBREW_PREFIX=$(/home/linuxbrew/.linuxbrew/bin/brew --prefix)
  export VIRTUALENVWRAPPER_PYTHON=${HOMEBREW_PREFIX}/bin/python3
  export WORKON_HOME=$HOME/.virtualenvs
  virtual_env_wrapper_path="${HOMEBREW_PREFIX}/bin/virtualenvwrapper.sh"
  if [ -f "${virtual_env_wrapper_path}" ]
  then
    source "${virtual_env_wrapper_path}"
  fi
fi


if [[ -d "$HOME/perl5" ]]
then
  export PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
  export PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
  export PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
  export PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
  export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;
fi

### Given a command name or alias, like 'll' the source is output, if found
function find_alias_or_function_with_command_name(){
  if (( $# != 1 )); then
    echo "Usage: find_alias_or_function_with_command_name <name>" >&2
    return 1
  fi

  local cmd_name="$1"
  local search_string="${aliases[$cmd_name]:-$cmd_name}"
  rg -. -F --glob '*.sh' -- "$search_string"
}

wait_for_keypress() {
    local kpmsg="Press any key to continue..."
    read "?$kpmsg"
}

copy-line-to-clipboard() {
  # Failures stay silent to keep the prompt intact; diagnose with setclip -v.
  { print -rn -- "$BUFFER" | setclip } 2>/dev/null || :
  return 0
}
zle -N copy-line-to-clipboard
# Alt+c
bindkey -M emacs '^[c' copy-line-to-clipboard
bindkey -M vicmd '^[c' copy-line-to-clipboard

# Path-segment editing: run the word widget with "/" removed from WORDCHARS,
# so these keys stop at each slash. Ctrl+W, Alt+D, Alt+F and Alt+B keep
# treating a whole path as one word.
_path_segment_widget() {
  local WORDCHARS=${WORDCHARS//\/}
  zle "${WIDGET#path-}"
}
for _path_widget in backward-kill-word kill-word backward-word forward-word; do
  zle -N "path-$_path_widget" _path_segment_widget
done
unset _path_widget
bindkey -M emacs '^[^?'    path-backward-kill-word  # Alt+Backspace
bindkey -M emacs '^[[3;3~' path-kill-word           # Alt+Delete
bindkey -M emacs '^[[1;3D' path-backward-word       # Alt+Left
bindkey -M emacs '^[[1;3C' path-forward-word        # Alt+Right

catpipe() {
  local file="$1"
  [[ -z "$file" ]] && { echo "Usage: catpipe <file>"; return 1; }
  [[ ! -f "$file" ]] && { echo "Not a file: $file"; return 1; }

  echo "$file | $(cat -- "$file")"
}

#SHIT
export_and_call_function(){
  local funcname=${1:u}
  local cmd=${1}
  export ${(P)funcname}=$(functions catpipe)
  local evalstr='eval $'"${funcname}"' && '"${1} ${@}"
  echo $evalstr
  shift
  zsh -c ${evalstr} _
}

function hello() {
  echo "Hello ${@}"
}

eacf(){
  local funcname="hello"
  export exported_func=export "${funcname}"
  eval "${funcname:u}=$(functions $exported_func)"
  echo 1 2 3 | xargs zsh -c 'eval $HELLO && hello ${@}' _
}
#SHIT END

to_binary() {
  local line input

  _to_binary_one() {
    local input="$1"

    # trim whitespace
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"

    if [[ ! "$input" =~ ^-?[0-9]+$ ]]; then
      echo "Error: '$input' is not a valid integer" >&2
      return 1
    fi

    if [[ "$input" -eq 0 ]]; then
      echo "0"
      return 0
    fi

    local sign=""
    if [[ "$input" -lt 0 ]]; then
      sign="-"
      input=$(( -input ))
    fi

    local result=""
    while (( input > 0 )); do
      result="$(( input % 2 ))$result"
      (( input /= 2 ))
    done

    echo "${sign}${result}"
  }

  if (( $# > 0 )); then
    # Convert each argument
    local rc=0
    for input in "$@"; do
      _to_binary_one "$input" || rc=$?
    done
    return $rc
  else
    # Convert each line from stdin
    local rc=0
    while IFS= read -r line; do
      _to_binary_one "$line" || rc=$?
    done
    return $rc
  fi
}

measure() {
  local start=$EPOCHREALTIME
  "$@"
  local command_exit_code=$?
  local end=$EPOCHREALTIME
  printf "Execution time: %.6f seconds\n" "$(( end - start ))"
  return "$command_exit_code"
}

deactivate_profiler(){
    export ZSH_PROFILER_ACTIVE=false
    zmodload -u zsh/zprof
    rm /tmp/zsh_profiler_active
}

if [[ ${ZSH_PROFILER_ACTIVE:-} == "1" || -f /tmp/zsh_profiler_active ]]
then
    zprof
fi
#Uncomment to profile (also enable the respective start part in the beginning of .zshenv)
#zprof


rerun_last_command() {
  fc -ln -1
}

alias rlc=rerun_last_command
function rlcc(){
  clear
  rerun_last_command
}

function rlccs(){
  source ~/.zshrc
  rlcc
}

(( $+aliases[setclip] )) && unalias setclip
setclip(){
  # Canonical implementation preserves line breaks; use -ntlb to trim them.
  command setclip "$@"
}

if [[ ${OS_CATEGORY:-} == "macos" && -n ${PIPX_BIN_DIR:-} ]]; then
  export PATH="$PIPX_BIN_DIR:$PATH"
  typeset -U PATH
fi
