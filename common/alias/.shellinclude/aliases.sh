#!/usr/bin/env zsh

alias c='clear'
alias x='exit'

function aliases_find(){
    rg -. --sort=path 'alias .* ?= ?.*[ $]?' </dev/null
}

function alias_find_and_print_names_only(){
    rg -. --sort=path -NI 'alias .* ?= ?.*[ $]?' </dev/null | sed -e 's/alias //' -e 's/=.*//g' | sort | uniq
}

alias c='clear'

alias cddf='cd "${DOTFILE_DIR:-$HOME/dotfiles}"'

alias cgrep="grep --color=always"

alias cux="chmod u+x "

alias fdisknl="sudo fdisk -l | awk '/Disk \/dev\/nvme/{p=1; printf \"\033[1m%s\033[0m\n\", \$0; next} /Disk \/dev\/loop/{p=0} p'"

find_home_files_linking_to_dotfiles(){
    find $HOME -type l -print0 | xargs -0 -I{} echo "echo -n '{} '; readlink -m '{}'" | sh | grep "${DOTFILE_DIR:-$HOME/dotfiles}"
}

alias getclip="xclip -selection c -o"

alias ll='ls -l --color=auto -h -B'

alias ls='ls --color=auto -h'

alias lt='ls -lrt'

alias nocm="grep -v '#' | awk NF"


alias paths='echo $PATH | tr ":" "\n" | sort'

alias psij="ps -ef | grep -i intellij | sed '1d' | awk '{print \$2}' | sort -n | uniq | xargs ps -p"

alias pskillij="ps -ef | grep -i intellij | sed '1d' | awk '{print \$2}' | sort -n | uniq | xargs kill -9"

#alias setclip='sed -z "$ s/\n$//" | xclip -selection clipboard'

alias sort1='tee >(sed 1d | sort) | head -n1' #Sorts while leaving header (first row) in place

alias sou='sort | uniq'

alias sout='sort | uniq | trim'

alias soz='source ~/.zshrc'

alias sozc='source ~/.zshrc && clear'

alias sumlines='paste -sd+ - | bc'

alias suz='subl ~/.zshrc'

alias sz='source ${HOME}/.zshrc'

alias vz='vim ${HOME}/.zshrc'

alias wcl='wc -l'

alias mx='chmod u+x'


function stat_printuniq(){
	local findResultWcL=$(find "$1" | wc -l)
	echo "Found $findResultWcL files. This may take a while."
	find "$1" -print0 | xargs -0 -I{} stat "{}" | grep -e Gid | tr -s ' ' | sort | uniq
}

alias ,gs='git status'
alias ,gc='git clone'
alias ,gr='git remote'
alias ,grv='git remote -v'

#Executes result of last command in xdg-open (for example opens find result in default program)
function xolast(){
	fc -ln -1 | xargs -I{} xdg-open "{}"
}

function cdl(){
    local repeat_times=${1:-1}
    local latest_dir

    for i in {1..$repeat_times}
    do
        #hacky and not very robust, fix
        latest_dir="$(ls -ldrt */ | tail -n1 | grep -o '[0-9]\{2\}:[0-9]\{2\} .*$' | cut -d ' ' -f2-)"
        cd "${latest_dir}"
    done
}

#TODO: fix, does not list all functions
function list_functions(){
	print -l ${(ok)functions} | grep -v '^_' | grep -v '^nvm' | sort
}
function list_aliases(){
	alias | cut -d'=' -f1 | sort
}
function list_functions_and_aliases() {
  (list_functions | sed 's/$/ | function/'; list_alias | sed 's/$/ | alias/') | sort | column -s'|' -t
}

function print_timestamp(){
	date +%Y-%m-%d_%H-%M-%S
}


function find_dirs_here(){
    find . -maxdepth 1 -type d | sed '1d'
}

function find_git_dirs_here(){
    find . -maxdepth 2 -name '.git' | cut -d '/' -f1-2 
}

function get_latest_file_in_dir(){
	dirname=$1
	ls -lrt "$1" | tail -n1 | rev | cut -d' ' -f1 | rev
}


alias ll.='ls --color=auto -lUd -- *(/) .*(/) .*(^/)'
alias rg.="rg -. --sort=path"
alias rgl.="rg -l -. --sort=path"

function rgl.os(){
    local search_term="${1}"
    rg -l -. "${search_term}" --sort=path </dev/null | xargs -I{} subl "{}"
}

function path_sort(){
    tr ":" "\n" | sort | awk NF | uniq
}

function alias_replace_with_function(){
    #works in IntelliJ at least
    local searchstr="(alias )(.*)(=['\"])(\(\))(\{)(.*)(}['\"])"
    local replacestr="function $2$4{\n\t$6\n}"
    #TODO carry out
}

alias vi=vim

function tf(){
  tail -f "$@"
}

function gR(){
  fd readme -tf -d1 . | head -n1 | glow
}
