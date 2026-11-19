#Always run (see https://zsh.sourceforge.io/Doc/Release/Files.html)

logger "ZDOT .zshenv started" 2>/dev/null || true
#set -o xtrace
# Profile startup: `ZSH_PROFILER_ACTIVE=1 zsh -i -c exit`, or create
# /tmp/zsh_profiler_active to profile every new shell. .zshrc prints the zprof report.
if [[ ${ZSH_PROFILER_ACTIVE:-} == "1" || -f /tmp/zsh_profiler_active ]]
then
    zmodload zsh/zprof
fi

# Use the repo-managed compinit path instead of Debian's global one.
skip_global_compinit=1

source "$HOME/.zshvars" #Environment variables
source "$HOME/.bin/common.sh" #now we can use function source_all_sh_files_in_subdir_of_home

source_localenv_non_interactive_files

cargo_env_file="$HOME/.cargo/env"
if [ -f "${cargo_env_file}" ]
then
  source "${cargo_env_file}"
fi

# ~/.local/bin (uv, pipx tools, cao, ...) for every zsh. sshd runs
# `ssh host '<cmd>'` as a plain, non-login `zsh -c`, which reads this file but
# neither .zprofile nor .zshrc. -U keeps each PATH entry once when .zprofile or
# .zshrc add it again.
typeset -U PATH
if [[ -d "$HOME/.local/bin" ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
