#!/usr/bin/env zsh

# MVND_PATH is exported by rules/mvnd when mvnd comes from a versioned /opt
# install. When mvnd is already on PATH (Homebrew) MVND_PATH is unset and
# there is nothing to add, so guard against expanding to "/bin:$PATH".
if [[ -n "${MVND_PATH:-}" && -d "${MVND_PATH}/bin" ]]; then
  export PATH="${MVND_PATH}/bin:$PATH"
fi
