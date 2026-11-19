#!/usr/bin/env zsh

# zellij's completion script is ~5000 lines; parsing it on every shell start
# costs ~80 ms. Cache it per zellij binary and zcompile it, so sourcing loads
# wordcode instead (~1 ms). Regenerated when the zellij binary is newer.
() {
  local zellij_bin="${commands[zellij]:A}"
  [[ -n "$zellij_bin" ]] || return 0

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local cache_file="$cache_dir/zellij_completion.zsh"

  if [[ ! -s "$cache_file" || "$zellij_bin" -nt "$cache_file" ]]; then
    local completion
    completion="$(
      zellij setup --generate-completion zsh 2>/dev/null |
        sed 's/^_zellij "\$@"/compdef _zellij zellij/'
    )"
    [[ "$completion" == *'compdef _zellij zellij'* ]] || return 0
    mkdir -p "$cache_dir" || return 0
    # Write under a per-shell name and rename, so a shell starting in
    # parallel never sources a half-written file.
    print -r -- "$completion" >"$cache_file.$$" || return 0
    mv -f "$cache_file.$$" "$cache_file" || return 0
    zcompile "$cache_file"
  fi

  source "$cache_file"
}
