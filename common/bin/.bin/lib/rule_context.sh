# shellcheck shell=bash
# Discovery never sources home policy or shell startup. An explicit root is
# still supported; otherwise dependencies belong to the executing source.
dotfiles_rule_context() {
  DOTFILE_DIR=${DOTFILE_DIR:-$1}
}

# dotfiles_rule_pin NAME: set NAME from the one literal `NAME=value` line in
# the source-local common/zsh/.zshvars, the single authoritative pin file that
# interactive shells source. The file is only read, never sourced or
# evaluated. A missing file, a missing or repeated line, or a value outside
# [A-Za-z0-9._-] (quotes, spaces, expansions, comments) is refused (return 1),
# so a rule cannot match on a value the shell would read differently.
dotfiles_rule_pin() {
  local name=${1:-} file="$DOTFILE_DIR/common/zsh/.zshvars" line value='' count=0
  local pattern='^[A-Za-z0-9][A-Za-z0-9._-]*$'
  case $name in
    ''|[!A-Z_]*|*[!A-Z0-9_]*)
      printf 'dotfiles_rule_pin: invalid pin name: %s\n' "$name" >&2
      return 1 ;;
  esac
  if [[ ! -f $file || ! -r $file ]]; then
    printf 'dotfiles_rule_pin: cannot read %s\n' "$file" >&2
    return 1
  fi
  while IFS= read -r line || [[ -n $line ]]; do
    case $line in
      "$name="*) value=${line#"$name="}; count=$((count + 1)) ;;
    esac
  done < "$file"
  if [[ $count -ne 1 || ! $value =~ $pattern ]]; then
    printf 'dotfiles_rule_pin: need exactly one plain %s=<version> line in %s\n' "$name" "$file" >&2
    return 1
  fi
  printf -v "$name" '%s' "$value"
}
