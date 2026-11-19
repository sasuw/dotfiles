export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  if [[ -r "$NVM_DIR/alias/default" ]]; then
    nvm_default_version="$(< "$NVM_DIR/alias/default")"
    nvm_default_bin="$NVM_DIR/versions/node/$nvm_default_version/bin"
    if [[ -d "$nvm_default_bin" ]]; then
      export PATH="$nvm_default_bin:$PATH"
    fi
  fi

  # Sourcing nvm.sh costs ~65 ms, and the default node is already on PATH, so
  # load nvm on its first use. Keep an nvm function that a caller defined
  # before sourcing this file (for example, a caller that already loaded NVM
  # or supplied its own implementation).
  if ! command -v nvm >/dev/null 2>&1; then
    function _nvm_lazy_load() {
      unset -f nvm _nvm_lazy_load
      source "$NVM_DIR/nvm.sh" --no-use
    }
    function nvm() {
      _nvm_lazy_load || return
      nvm "$@"
    }
  fi
  if [[ -n "$nvm_default_bin" && ! -d "$nvm_default_bin" ]]; then
    nvm use --silent default >/dev/null
  fi
  unset nvm_default_version nvm_default_bin

  # Auto-switch node version on cd into a directory with an .nvmrc, and
  # revert to the nvm default on cd back out of one. zsh-only (autoload,
  # add-zsh-hook): Bash consumers also source this file to reuse nvm_which,
  # so this block must not run there.
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    autoload -U add-zsh-hook

    # Set REPLY to the nearest .nvmrc at or above directory $1, like
    # nvm_find_nvmrc, but without loading nvm or forking.
    function _nvmrc_find() {
      local dir="$1"
      [[ -n "$dir" ]] || return 1
      while :; do
        if [[ -f "$dir/.nvmrc" ]]; then
          REPLY="$dir/.nvmrc"
          return 0
        fi
        [[ "$dir" == / ]] && return 1
        dir="${dir:h}"
      done
    }

    function load-nvmrc() {
      local REPLY
      if _nvmrc_find "$PWD"; then
        local nvmrc_path="$REPLY"
        # Load nvm here; inside $(...) the stub would load it per subshell.
        (( ${+functions[_nvm_lazy_load]} )) && { _nvm_lazy_load || return; }
        local nvmrc_node_version
        nvmrc_node_version="$(nvm version "$(< "$nvmrc_path")")"

        if [[ "$nvmrc_node_version" == 'N/A' ]]; then
          echo "nvm: no installed version matches $(< "$nvmrc_path") (run 'nvm install' to add it)"
        elif [[ "$nvmrc_node_version" != "$(nvm version)" ]]; then
          nvm use --silent
        fi
      # Only a loaded nvm can have switched away from the default.
      elif (( ${+functions[nvm_find_nvmrc]} )) && _nvmrc_find "${OLDPWD:-}" &&
        [[ "$(nvm version)" != "$(nvm version default)" ]]; then
        nvm use --silent default
      fi
    }
    add-zsh-hook chpwd load-nvmrc
    load-nvmrc
  fi
fi

nvm_which(){
  local which_arg="$1"
  nvm --version > /dev/null #ensure nvm is loaded
  local execpath=$HOME/.nvm/versions/node/$(nvm current)/bin/"$which_arg"
  if [[ -f $execpath || -L $execpath ]]
  then
    echo "$execpath"
    return 0
  else
    echo "$which_arg not found"
    return 1
  fi
}
