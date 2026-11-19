# ~/.bashrc
logger "DOT .bashrc started" 2>/dev/null || true

# Source shared shell logic (zsh has separate syntax checks).
# shellcheck source=/dev/null
source "$HOME/.bin/common.sh"

# Bash does not load the zsh .shellinclude directory.
# shellcheck source=common/bin/.bin/lib/dotfiles_root.sh
source "$HOME/.bin/lib/dotfiles_root.sh"
dotfiles_init_root ""
# Optional user-owned include; absent from a generic-only install.
# shellcheck source=/dev/null
[ ! -r "$HOME/.shellinclude/01-personal-env.sh" ] || source "$HOME/.shellinclude/01-personal-env.sh"

# History settings
HISTFILE=~/.bash_history
HISTSIZE=1000000
HISTCONTROL=ignoredups:ignorespace
HISTTIMEFORMAT='%F %T '
shopt -s histappend
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# Shell options
shopt -s cmdhist
shopt -s checkwinsize

# Define prompt spacing and separator
UNICODE_HAIR_SPACE=$'\u200A'
PROMPT_SPACE=$UNICODE_HAIR_SPACE
PROMPT_SEPARATOR="${PROMPT_SPACE}|${PROMPT_SPACE}"
prompt_last_status=0
prompt_timer_show=0us

prompt_timer_now_us() {
  local epoch seconds micros

  if [[ -n ${EPOCHREALTIME:-} ]]; then
    epoch=${EPOCHREALTIME/,/.}
    seconds=${epoch%%.*}
    if [[ $epoch == *.* ]]; then
      micros=${epoch#*.}
    else
      micros=0
    fi
    seconds=${seconds//[^0-9]/}
    micros=${micros//[^0-9]/}
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
    prompt_timer_show=${h}h${m}m
  elif (( m > 0 )); then
    prompt_timer_show=${m}m${s}s
  elif (( s >= 10 )); then
    prompt_timer_show=${s}.$((ms / 100))s
  elif (( s > 0 )); then
    prompt_timer_show=${s}.$(printf %03d "$ms")s
  elif (( ms >= 100 )); then
    prompt_timer_show=${ms}ms
  elif (( ms > 0 )); then
    prompt_timer_show=${ms}.$((us / 100))ms
  else
    prompt_timer_show=${us}us
  fi
}

prompt_timer_stop() {
  local delta_us

  if [[ ${prompt_timer_command_active:-0} -ne 1 ]] || [[ -z ${prompt_timer_started_at_us:-} ]]; then
    prompt_timer_show=${prompt_timer_show:-0us}
    return
  fi

  prompt_timer_now_us
  delta_us=$((REPLY - prompt_timer_started_at_us))
  prompt_timer_format_us "$delta_us"
  unset prompt_timer_started_at_us
  prompt_timer_command_active=0
}

prompt_timer_debug() {
  [[ ${prompt_timer_in_prompt:-0} -eq 1 ]] && return
  [[ ${BASH_COMMAND:-} == prompt_command ]] && return

  if [[ ${prompt_timer_command_active:-0} -ne 1 ]]; then
    prompt_timer_now_us
    prompt_timer_started_at_us=$REPLY
    prompt_timer_command_active=1
  fi
}

prompt_command() {
  local last_status=$?

  prompt_timer_in_prompt=1
  prompt_timer_stop
  prompt_last_status=$last_status
  history -a
  if [[ -n ${prompt_previous_command:-} ]]; then
    eval "$prompt_previous_command"
  fi
  prompt_timer_in_prompt=0
  return "$last_status"
}

# Git branch function: shortened to show just branch with dirty marker
git_branch() {
  local branch dirty
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null)
    if [[ -n "$branch" ]]; then
      if ! git diff --quiet --ignore-submodules --cached || ! git diff --quiet --ignore-submodules || [[ -n $(git ls-files --others --exclude-standard) ]]; then
        dirty="*"
      fi
      [[ ${#branch} -gt 15 ]] && branch="${branch:0:15}…"
      echo -n "${branch}${dirty}"
    fi
  fi
}

# Set PS1 (prompt string)
PS1='\[\e[35m\]${prompt_last_status:-0}\[\e[0m\]'"$PROMPT_SEPARATOR"'\[\e[33m\]${prompt_timer_show:-0us}\[\e[0m\]'"$PROMPT_SEPARATOR"'\[\e[32m\]\u@\[\e[33m\]\h\[\e[0m\]'"$PROMPT_SEPARATOR"'\[\e[36m\]$(git_branch)\[\e[0m\]'"$PROMPT_SEPARATOR"'\[\e[34m\]\w\[\e[0m\] \$ '

# Environment variables
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/.local/bin
export PATH=$PATH:/usr/local/swift/usr/bin:$HOME/bin:$HOME/perl5/bin
export EDITOR=vim
export VISUAL=vim
export TIME_STYLE=long-iso
export MANPATH="/usr/share/man:$MANPATH"

# Functions
remove_multiline_history() {
  cp ~/.bash_history ~/.bash_history.bak
  awk '/^[0-9]+/{if (NR != 1) print buffer; buffer=$0; next} {buffer=buffer " " $0} END {print buffer}' ~/.bash_history > ~/.bash_history.cleaned
  mv ~/.bash_history.cleaned ~/.bash_history
  history -r ~/.bash_history
}
xon() { filetype=$1; xdg-open "$(lsNewestFileOfFileType "$filetype")"; }
xof() { xdg-open "$(lsNewestFile)"; }

subdir_exec() {
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

# Brew setup
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  for brew_path in /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin; do
    PATH=":${PATH}:"
    PATH="${PATH//:${brew_path}:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"
    PATH="${PATH:+$PATH:}${brew_path}"
  done
  export PATH

fi

if [[ -f "$HOME/.shellinclude/java-exports.sh" ]]; then
  # shellcheck source=parts/application/java/exports/.shellinclude/java-exports.sh
  source "$HOME/.shellinclude/java-exports.sh"
fi

# Keyboard settings (Bash alternative to bindkey -e)
set -o emacs  # or `set -o vi` if you prefer vi-style bindings

# Maven: source the stowed includes in glob order, the same order zsh gets via
# source_all_sh_files_in_subdir_of_home. Listing individual files here meant the
# versions file was sourced last, after its consumers, and any rename in
# parts/application/mvn silently broke bash login shells.
for _mvn_include in "$HOME"/.shellinclude/[0-9][0-9]-maven-*.sh \
                    "$HOME"/.shellinclude/maven-*.sh; do
  # Runtime selection may also include user-owned Maven snippets.
  # shellcheck source=/dev/null
  [ -r "$_mvn_include" ] && source "$_mvn_include"
done
unset _mvn_include

# Optional initialization belongs to the separately installed fzf.
# shellcheck source=/dev/null
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

prompt_previous_command=${PROMPT_COMMAND:-}
PROMPT_COMMAND=prompt_command
trap prompt_timer_debug DEBUG

