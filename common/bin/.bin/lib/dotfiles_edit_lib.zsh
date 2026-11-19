# Shared Git workflow for dotfiles-editing commands. Source from zsh.
# Consumers provide die(), and call prepare before changing the target.
# prepare sets dotfiles_edit_{file,root,relative,branch,remote}; consumers can
# localize these names in their calling function (zsh dynamic scope).

dotfiles_edit_select_file() {
  local layer="$1" file="$2" relative="$3" resolved_layer owning_root
  [[ -n "$layer" || -n "$file" ]] || die 'specify --layer-root or --file'
  if [[ -n "$layer" ]]; then
    [[ -d "$layer" ]] || die 'layer root must be an existing directory'
    resolved_layer="${layer:A}"
    [[ -n "$file" ]] || file="$resolved_layer/$relative"
  fi
  [[ -f "$file" ]] || die "file not found: $file"
  dotfiles_edit_file="${file:A}"
  if [[ -n "$layer" ]]; then
    [[ "$dotfiles_edit_file" == "$resolved_layer/"* ]] \
      || die 'FILE resolves outside the selected layer root'
    if (( $+commands[git] )) &&
       owning_root="$(git -C "${dotfiles_edit_file:h}" rev-parse --show-toplevel 2>/dev/null)"; then
      [[ "${owning_root:A}" == "$resolved_layer" ]] \
        || die 'FILE belongs to a different Git repository than the selected layer root'
    fi
  fi
}

dotfiles_edit_prepare_git() {
  (( $+commands[git] )) || die 'git is required; use --no-git to append only'
  dotfiles_edit_file="${1:A}"
  dotfiles_edit_root="$(git -C "${dotfiles_edit_file:h}" rev-parse --show-toplevel)" \
    || die 'FILE must be in a Git working tree; use --no-git to append only'
  dotfiles_edit_relative="${dotfiles_edit_file#"$dotfiles_edit_root/"}"
  git -C "$dotfiles_edit_root" --literal-pathspecs ls-files --error-unmatch -- "$dotfiles_edit_relative" >/dev/null 2>&1 \
    || die 'FILE must be tracked; use --no-git to append only'
  local git_state
  git_state="$(git -C "$dotfiles_edit_root" --literal-pathspecs status --porcelain -- "$dotfiles_edit_relative")" \
    || die 'cannot check FILE for existing changes'
  [[ -z "$git_state" ]] \
    || die 'FILE has existing changes; commit them first or use --no-git'
  dotfiles_edit_branch="$(git -C "$dotfiles_edit_root" symbolic-ref --quiet --short HEAD)" \
    || die 'cannot push from a detached HEAD; use --no-git to append only'
  dotfiles_edit_remote="$(git -C "$dotfiles_edit_root" config --get "branch.$dotfiles_edit_branch.pushRemote")" \
    || dotfiles_edit_remote="$(git -C "$dotfiles_edit_root" config --get remote.pushDefault)" \
    || dotfiles_edit_remote="$(git -C "$dotfiles_edit_root" config --get "branch.$dotfiles_edit_branch.remote")" \
    || dotfiles_edit_remote=origin
  [[ "$dotfiles_edit_remote" != . ]] \
    || die 'push remote is local (.); configure a push remote or use --no-git'
  git -C "$dotfiles_edit_root" remote get-url --push --all "$dotfiles_edit_remote" >/dev/null \
    || die 'no push remote configured; use --no-git to append only'
}

dotfiles_edit_preview_git() {
  print -r -- "Would stage and commit $dotfiles_edit_relative, then push $dotfiles_edit_branch to $dotfiles_edit_remote."
}

dotfiles_edit_publish() {
  local message="$1" noun="$2"
  git -C "$dotfiles_edit_root" --literal-pathspecs add -- "$dotfiles_edit_relative" \
    || die "$noun appended, but staging failed; changes were kept"
  git -C "$dotfiles_edit_root" --literal-pathspecs commit --only -m "$message" -- "$dotfiles_edit_relative" \
    || die "$noun appended, but commit failed; changes were kept"
  git -C "$dotfiles_edit_root" push "$dotfiles_edit_remote" "HEAD:refs/heads/$dotfiles_edit_branch" \
    || die "$noun committed, but push failed; retry the push after resolving the error"
}
