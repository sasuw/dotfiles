# Point GOROOT at /usr/local/go only where that installation exists. A go
# found elsewhere on PATH (for example ~/.local/bin/go on macOS)
# finds its own GOROOT, and a GOROOT that does not exist breaks it.
if [[ -z "${GOROOT:-}" && -d /usr/local/go ]]; then
  export GOROOT=/usr/local/go
fi
export GOPATH="${GOPATH:-$HOME/go}"
export GOBIN="${GOBIN:-$GOPATH/bin}"
export GOMODCACHE="${GOMODCACHE:-$GOPATH/pkg/mod}"
export GOCACHE="${GOCACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/go-build}"

typeset -gU path
path=(${GOROOT:+"$GOROOT/bin"} "$GOBIN" "${path[@]}")
export PATH
