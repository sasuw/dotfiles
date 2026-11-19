alias xo='xdg-open'

alias l='ls -hB --color=auto --hide "#*#"'
alias ll='ls -lhB --color=auto --hide "#*#"'
alias lt='ls -lrt --color=auto '
alias la='ls -la --color=auto '
alias ll.='ls --color=auto -lUd -- *(N/) .*(N/) .*(N^/) *(N^/)'

alias jcue='(){sudo journalctl -u $1 -e | grep -v "^~";}'