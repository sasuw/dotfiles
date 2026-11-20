# Shared destination selection and Git workflow for dotfiles-editing commands.
# Source from zsh. Consumers provide die() (exit 1) and usage_error() (exit 2),
# and call prepare before changing the target.
# select sets dotfiles_edit_{file,layer}; prepare sets
# dotfiles_edit_{file,root,relative,branch,remote}. Consumers can localize
# these names in their calling function (zsh dynamic scope).
#
# Source registry: ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiletracker/config,
# read as data with the contract of dft_load_registry and dft_add_source in
# envmaker's bin/source_registry.sh. Nothing in it is evaluated, sourced,
# globbed or expanded, except a leading ~, $HOME or ${HOME} alone or before
# a slash. The registry functions start with
# `emulate -L zsh`, so startup-file options cannot change parsing; ERR_EXIT is
# off there, so every failure is checked explicitly.

# Option parsing for --layer-root, -f/--file, --file=, --source and --source=.
# Sets REPLY to the number of arguments consumed (0: "$1" is no such option)
# and the caller's dotfiles_edit_{layer,file,source}_option. Each option may
# be given once and must not be empty; --source and --layer-root exclude each
# other. Every violation is a usage error.
dotfiles_edit_parse_destination_option() {
  emulate -L zsh
  local option="$1" value
  REPLY=0
  case "$option" in
    --layer-root)
      (( $# >= 2 )) || usage_error "$option needs a directory"
      [[ -z "$dotfiles_edit_layer_option" ]] || usage_error 'layer root was specified more than once'
      [[ -n "$2" ]] || usage_error 'layer root is empty'
      [[ -z "$dotfiles_edit_source_option" ]] || usage_error '--source cannot be combined with --layer-root'
      dotfiles_edit_layer_option="$2"; REPLY=2 ;;
    -f|--file|--file=*)
      if [[ "$option" == --file=* ]]; then
        value="${option#--file=}"; REPLY=1
      else
        (( $# >= 2 )) || usage_error "$option needs a file"
        value="$2"; REPLY=2
      fi
      [[ -z "$dotfiles_edit_file_option" ]] || usage_error 'file was specified more than once'
      [[ -n "$value" ]] || usage_error 'file is empty'
      dotfiles_edit_file_option="$value" ;;
    --source|--source=*)
      if [[ "$option" == --source=* ]]; then
        value="${option#--source=}"; REPLY=1
      else
        (( $# >= 2 )) || usage_error "$option needs a source ID"
        value="$2"; REPLY=2
      fi
      [[ -z "$dotfiles_edit_source_option" ]] || usage_error 'source was specified more than once'
      [[ -n "$value" ]] || usage_error 'source is empty'
      dotfiles_edit_valid_source_id "$value" \
        || usage_error "invalid source ID: $value (use letters, digits, '_' and '-', starting with a letter or digit)"
      [[ -z "$dotfiles_edit_layer_option" ]] || usage_error '--source cannot be combined with --layer-root'
      dotfiles_edit_source_option="$value" ;;
  esac
}

dotfiles_edit_valid_source_id() {
  emulate -L zsh
  local LC_ALL=C
  [[ "$1" =~ '^[A-Za-z0-9][A-Za-z0-9_-]*$' ]]
}

# Sets REPLY to the registry path; an empty XDG_CONFIG_HOME counts as unset.
dotfiles_edit_registry_path() {
  REPLY="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiletracker/config"
}

# Expands only ~, $HOME and ${HOME}, alone or followed by a slash; REPLY.
dotfiles_edit_expand_home() {
  emulate -L zsh
  local value="$1"
  case "$value" in
    '~'|'$HOME'|'${HOME}') REPLY="$HOME" ;;
    '~/'*) REPLY="$HOME/${value#'~/'}" ;;
    '$HOME/'*) REPLY="$HOME/${value#'$HOME/'}" ;;
    '${HOME}/'*) REPLY="$HOME/${value#'${HOME}/'}" ;;
    *) REPLY="$value" ;;
  esac
}

# Reads the registry once per process. Returns 0 when it was parsed, 1 when
# it is invalid (reason in dotfiles_edit_registry_error), 2 when it does not
# exist. Sets dotfiles_edit_registry_{file,mode,ids,roots,legacy}; mode is
# stack or legacy. Stack roots are existing directories in the canonical form
# of dotfiles_edit_canonical_path.
dotfiles_edit_load_registry() {
  emulate -L zsh
  setopt extended_glob
  if [[ -n "${dotfiles_edit_registry_status-}" ]]; then
    return "$dotfiles_edit_registry_status"
  fi
  local config line key value id root existing legacy_seen=0
  dotfiles_edit_registry_path
  config="$REPLY"
  typeset -g dotfiles_edit_registry_file="$config" dotfiles_edit_registry_mode=''
  typeset -g dotfiles_edit_registry_legacy='' dotfiles_edit_registry_error=''
  typeset -ga dotfiles_edit_registry_ids dotfiles_edit_registry_roots
  dotfiles_edit_registry_ids=()
  dotfiles_edit_registry_roots=()
  typeset -g dotfiles_edit_registry_status=1
  if [[ ! -e "$config" && ! -L "$config" ]]; then
    dotfiles_edit_registry_status=2
    return 2
  fi
  if [[ ! -f "$config" || ! -r "$config" ]]; then
    dotfiles_edit_registry_error="source registry is not a readable file: $config"
    return 1
  fi
  local -a lines
  lines=()
  # The last line counts even without a final line break.
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
  done <"$config" || {
    dotfiles_edit_registry_error="cannot read source registry: $config"
    return 1
  }
  for line in "${lines[@]}"; do
    line="${${line##[[:space:]]#}%%[[:space:]]#}"
    [[ -n "$line" && "$line" != '#'* ]] || continue
    if [[ "$line" == *=* ]]; then
      key="${${${line%%=*}##[[:space:]]#}%%[[:space:]]#}"
      value="${${${line#*=}##[[:space:]]#}%%[[:space:]]#}"
      case "$key" in
        source.*)
          id="${key#source.}"
          if ! dotfiles_edit_valid_source_id "$id"; then
            dotfiles_edit_registry_error="invalid source ID in $config: $id"
            return 1
          fi
          root="$value"
          # Quoting is literal pairing only; no escaping or shell evaluation.
          if [[ "$root" == [\"\']* ]]; then
            if (( ${#root} >= 2 )) && [[ "${root[1]}" == "${root[-1]}" ]]; then
              root="${root[2,-2]}"
            else
              dotfiles_edit_registry_error="unmatched source path quote for $id in $config"
              return 1
            fi
          fi
          if [[ -z "$root" ]]; then
            dotfiles_edit_registry_error="empty source path for $id in $config"
            return 1
          fi
          dotfiles_edit_expand_home "$root"
          root="$REPLY"
          if ! dotfiles_edit_canonical_path -d "$root"; then
            dotfiles_edit_registry_error="source directory not found ($id): $root"
            [[ ! -d "$root" ]] \
              || dotfiles_edit_registry_error="source directory cannot be entered ($id): $root"
            return 1
          fi
          root="$REPLY"
          for existing in "${dotfiles_edit_registry_ids[@]}"; do
            if [[ "$existing" == "$id" ]]; then
              dotfiles_edit_registry_error="duplicate source ID in $config: $id"
              return 1
            fi
          done
          for existing in "${dotfiles_edit_registry_roots[@]}"; do
            if [[ "$existing" -ef "$root" ]]; then
              dotfiles_edit_registry_error="repeated physical source root ($id): $root"
              return 1
            fi
          done
          dotfiles_edit_registry_ids+=("$id")
          dotfiles_edit_registry_roots+=("$root")
          ;;
        dotfiles_dir|dotfile_dir)
          if (( ! legacy_seen )); then
            dotfiles_edit_unquote "$value"
            dotfiles_edit_registry_legacy="$REPLY"
          fi
          legacy_seen=1
          ;;
      esac
    else
      if (( ! legacy_seen )); then
        dotfiles_edit_unquote "$line"
        dotfiles_edit_registry_legacy="$REPLY"
      fi
      legacy_seen=1
    fi
  done
  if (( ${#dotfiles_edit_registry_ids} )); then
    if (( legacy_seen )); then
      dotfiles_edit_registry_error="cannot mix dotfiles_dir and source entries in $config"
      return 1
    fi
    dotfiles_edit_registry_mode=stack
  elif (( legacy_seen )); then
    dotfiles_edit_registry_mode=legacy
  else
    dotfiles_edit_registry_error="no source registered in $config"
    return 1
  fi
  dotfiles_edit_registry_status=0
}

# dotfiles_edit_lexical_directory NAME
# Sets REPLY to the path that Bash `cd -L -- NAME` tries first: NAME made
# absolute with the logical working directory, then reduced left to right.
# An empty or `.` component is dropped, `..` drops the component before it
# (none at the root), and every other component must make the path so far an
# existing directory. Returns 1 when one does not: Bash has no such path then
# and changes to NAME as the kernel resolves it.
dotfiles_edit_lexical_directory() {
  emulate -L zsh
  local name="$1" working="$PWD" part
  local -a parts
  if [[ "$name" != /* ]]; then
    # PWD is the logical directory only while it names the current one.
    if [[ "$working" != /* || ! "$working" -ef . ]]; then
      dotfiles_edit_physical_directory . || return 1
      working="$REPLY"
    fi
    name="$working/$name"
  fi
  for part in "${(@s:/:)name}"; do
    case "$part" in
      ''|.) ;;
      ..) (( ! ${#parts} )) || parts[-1]=() ;;
      *)
        parts+=("$part")
        [[ -d "/${(j:/:)parts}" ]] || return 1 ;;
    esac
  done
  REPLY="/${(j:/:)parts}"
}

# dotfiles_edit_physical_directory DIRECTORY
# Changes to DIRECTORY in a subshell, as the kernel resolves it, and sets REPLY
# to the working directory the kernel then reports (`pwd -P`). Returns 1 when
# the change fails (not a directory, no search permission, a symlink loop, a
# name that is too long) or the reported path is not that directory.
dotfiles_edit_physical_directory() {
  emulate -L zsh
  local directory="$1" resolved
  # A leading ./ keeps -, +N and -N from naming a directory-stack entry.
  [[ "$directory" == /* ]] || directory="./$directory"
  # The x keeps a line break at the end of the path from being stripped.
  resolved="$(
    cdpath=()
    builtin cd -q -P -- "$directory" >/dev/null 2>&1 && builtin pwd -P && print -n x
  )" || return 1
  resolved="${resolved%$'\n'x}"
  [[ "$resolved" == /* && "$resolved" -ef "$directory" ]] || return 1
  REPLY="$resolved"
}

# dotfiles_edit_canonical_path -d|-f NAME
# Sets REPLY to the canonical path of directory (-d) or regular file (-f)
# NAME, or returns 1. A directory follows dft_add_source step by step:
#   1. NAME must be an existing directory by kernel resolution (`[[ -d ]]`);
#   2. `cd -- NAME` must succeed. Bash `cd -L` changes to the lexical path
#      (dotfiles_edit_lexical_directory) when it has one and can enter it,
#      otherwise to NAME as the kernel resolves it;
#   3. the result is `pwd -P` there.
# The change is a real `cd`, so missing search permission, a symlink loop and
# an over-long name fail here as they do there. Two differences: a directory
# named `-` is refused, because Bash `cd -- -` changes to OLDPWD, not to it
# (write ./-); and a leading // that Bash keeps in its result is one slash
# here, as the kernel reports the same directory.
# A file is a regular file by kernel resolution; its directory is resolved
# as above, and a symlink in the last component is then followed. The result
# is a physical directory plus a name that is not a symlink.
# Shared by every registry root, layer and file.
dotfiles_edit_canonical_path() {
  emulate -L zsh
  local kind="$1" name="${2-}" directory base='' candidate file linked
  local -a candidates
  case "$kind" in
    -d|-f) ;;
    *) die "internal error: dotfiles_edit_canonical_path kind $kind" ;;
  esac
  [[ -n "$name" ]] || return 1
  if [[ "$kind" == -d ]]; then
    [[ "$name" != - && -d "$name" ]] || return 1
    directory="$name"
  else
    [[ -f "$name" ]] || return 1
    directory="${name:h}" base="${name:t}"
  fi
  candidates=()
  if dotfiles_edit_lexical_directory "$directory"; then
    candidates+=("$REPLY")
  fi
  candidates+=("$directory")
  for candidate in "${candidates[@]}"; do
    dotfiles_edit_physical_directory "$candidate" || continue
    [[ "$kind" == -f ]] || return 0
    file="${REPLY%/}/$base"
    [[ -f "$file" ]] || continue
    if [[ -L "$file" ]]; then
      # Follow the link, then take its directory from the kernel again.
      linked="${file:P}"
      dotfiles_edit_physical_directory "${linked:h}" || return 1
      linked="${REPLY%/}/${linked:t}"
      [[ -f "$linked" && ! -L "$linked" && "$linked" -ef "$file" ]] || return 1
      file="$linked"
    fi
    REPLY="$file"
    return 0
  done
  return 1
}

# Sets REPLY to $1 without one matching pair of outer quotes (dft_unquote).
dotfiles_edit_unquote() {
  emulate -L zsh
  REPLY="$1"
  if (( ${#REPLY} >= 2 )) && [[ "${REPLY[1]}" == [\"\'] && "${REPLY[1]}" == "${REPLY[-1]}" ]]; then
    REPLY="${REPLY[2,-2]}"
  fi
}

# Sets REPLY to the canonical registered root of source ID, or dies.
dotfiles_edit_source_root() {
  emulate -L zsh
  local id="$1" index
  dotfiles_edit_valid_source_id "$id" || die "invalid source ID: $id"
  dotfiles_edit_load_registry
  case $? in
    0) ;;
    2) die "--source requires a source registry: $dotfiles_edit_registry_file not found" ;;
    *) die "$dotfiles_edit_registry_error" ;;
  esac
  [[ "$dotfiles_edit_registry_mode" == stack ]] \
    || die "--source requires stack configuration (source.<id> entries) in $dotfiles_edit_registry_file"
  index="${dotfiles_edit_registry_ids[(Ie)$id]}"
  (( index )) || die "unknown destination source: $id"
  REPLY="${dotfiles_edit_registry_roots[$index]}"
}

# Sets the caller's dotfiles_edit_scan_roots to every registered root:
# all stack roots, or the home-expanded legacy root. Empty without a registry.
# An invalid registry, a missing legacy root or a root that cannot be listed
# dies, so a duplicate scan never silently skips a source. The last check is
# stricter than envmaker, which accepts a root it can enter but not read.
dotfiles_edit_registered_roots() {
  emulate -L zsh
  local reason root
  local invalid='source registry is invalid; the duplicate check cannot cover all sources'
  dotfiles_edit_scan_roots=()
  dotfiles_edit_load_registry
  case $? in
    0) ;;
    2) return 0 ;;
    *) die "$invalid: $dotfiles_edit_registry_error" ;;
  esac
  if [[ "$dotfiles_edit_registry_mode" == stack ]]; then
    dotfiles_edit_scan_roots=("${dotfiles_edit_registry_roots[@]}")
  else
    dotfiles_edit_expand_home "$dotfiles_edit_registry_legacy"
    reason="legacy source directory not found: $REPLY"
    [[ ! -d "$REPLY" ]] || reason="legacy source directory cannot be entered: $REPLY"
    [[ -n "$REPLY" ]] || reason="legacy source path is empty in $dotfiles_edit_registry_file"
    dotfiles_edit_canonical_path -d "$REPLY" || die "$invalid: $reason"
    dotfiles_edit_scan_roots=("$REPLY")
  fi
  for root in "${dotfiles_edit_scan_roots[@]}"; do
    [[ -r "$root" ]] || die "$invalid: source directory is not readable: $root"
  done
}

# dotfiles_edit_select_file LAYER FILE RELATIVE [SOURCE KIND]
# Selects the target from --layer-root LAYER, --file FILE or --source SOURCE.
# RELATIVE is the standard include under a layer. With SOURCE and no FILE,
# ROOT/${RELATIVE:h}/zz-SOURCE-KIND.sh wins over ROOT/RELATIVE when it exists.
# Sets dotfiles_edit_file (canonical) and dotfiles_edit_layer (the canonical
# selected root, or empty for FILE alone).
dotfiles_edit_select_file() {
  emulate -L zsh
  local layer="$1" file="$2" relative="$3" source_id="${4-}" kind="${5-}"
  local resolved_layer='' owning_root candidate
  [[ -n "$layer" || -n "$file" || -n "$source_id" ]] \
    || die 'specify --layer-root, --source or --file'
  [[ -z "$layer" || -z "$source_id" ]] \
    || die '--source cannot be combined with --layer-root'
  if [[ -n "$source_id" ]]; then
    [[ -n "$kind" ]] || die 'internal error: no include kind for --source'
    dotfiles_edit_source_root "$source_id"
    resolved_layer="$REPLY"
    if [[ -z "$file" ]]; then
      local -a candidates
      candidates=("$resolved_layer/${relative:h}/zz-$source_id-$kind.sh" "$resolved_layer/$relative")
      for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
          file="$candidate"
          break
        fi
      done
      [[ -n "$file" ]] \
        || die "source $source_id has no include: neither ${candidates[1]} nor ${candidates[2]} exists; create one or pass --file"
    fi
  elif [[ -n "$layer" ]]; then
    dotfiles_edit_canonical_path -d "$layer" || die 'layer root must be an existing directory'
    resolved_layer="$REPLY"
    [[ -n "$file" ]] || file="$resolved_layer/$relative"
  fi
  dotfiles_edit_canonical_path -f "$file" || die "file not found: $file"
  dotfiles_edit_file="$REPLY"
  # The duplicate and syntax checks read FILE; unread, they would pass.
  [[ -r "$dotfiles_edit_file" ]] || die "file is not readable: $file"
  dotfiles_edit_layer="$resolved_layer"
  if [[ -n "$resolved_layer" ]]; then
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
