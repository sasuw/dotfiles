#!/usr/bin/env zsh

## xargsq is "xargs quoted"
function xargsq(){
  xargs -I{} "$@" "{}"
}

alias xaq='xargsq'

#Useful for e.g. listing fail paths with fd and feeding them to another
#program which does not output the file processed
function xargs_quoted_with_arg_output(){
  local before_path_args="$1"
  local after_path_args="${2:-}"
  local echo_cmd="echo -n '{}' '| '; "
  local actual_cmd="${before_path_args} {} ${after_path_args}"
  xargs -I{} zsh -c "${echo_cmd} ${actual_cmd}"
}

alias xao='xargs_quoted_with_arg_output'