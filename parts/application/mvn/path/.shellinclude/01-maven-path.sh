# Versions come from 00-maven-versions-env.sh, which sorts first. The fallbacks
# below only apply when this file is sourced on its own without the versions
# file having run.
: "${maven3_version:=3.10.0}"
: "${maven4_version:=4.0.0-rc-6}"
: "${maven36_version:=3.6.3}"
: "${maven38_version:=3.8.8}"
export maven3_version maven4_version maven36_version maven38_version

_maven_home_candidates_for_version() {
  local version="$1"

  printf '%s\n' \
    "/opt/apache-maven-${version}" \
    "/opt/apache-${version}"
}

_maven_brew_home_candidates() {
  local prefix

  for prefix in \
    "${HOMEBREW_PREFIX:-}" \
    /usr/local \
    /opt/homebrew \
    /home/linuxbrew/.linuxbrew; do
    [[ -n "${prefix}" ]] || continue
    printf '%s\n' "${prefix}/opt/maven/libexec"
  done
}

_maven_resolve_home() {
  local version="${1:-${maven3_version}}"
  local candidate

  while IFS= read -r candidate; do
    if [[ -x "${candidate}/bin/mvn" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(_maven_home_candidates_for_version "${version}")

  if [[ "${version}" == "${maven3_version}" ]]; then
    # An installer may link its newest release here, so a machine whose
    # installed release differs from the pin keeps
    # a working default Maven.
    if [[ -x /opt/apache-maven/bin/mvn ]]; then
      printf '%s\n' /opt/apache-maven
      return 0
    fi
    while IFS= read -r candidate; do
      if [[ -x "${candidate}/bin/mvn" ]]; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    done < <(_maven_brew_home_candidates)
  fi

  return 1
}

_maven_resolve_mvn() {
  local version="${1:-${maven3_version}}"
  local maven_home

  if maven_home="$(_maven_resolve_home "${version}")"; then
    printf '%s\n' "${maven_home}/bin/mvn"
    return 0
  fi

  if [[ "${version}" == "${maven3_version}" ]]; then
    _maven_mvn_on_path
  fi
}

# Path of an mvn executable on PATH. `command -v mvn` would print the name of
# the mvn shell function instead.
_maven_mvn_on_path() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    whence -p mvn 2>/dev/null
  else
    type -P mvn 2>/dev/null
  fi
}

_maven_prepend_path() {
  local path_entry="$1"

  [[ -d "${path_entry}" ]] || return 0
  case ":${PATH}:" in
    *:"${path_entry}":*) ;;
    *) PATH="${path_entry}:${PATH}" ;;
  esac
}

_maven_refresh_env() {
  local maven_home

  maven_home="$(_maven_resolve_home "${maven3_version}" || true)"
  [[ -n "${maven_home}" ]] || return 0

  export MAVEN_HOME="${maven_home}"
  export M2_HOME="${maven_home}"
  export M2="${maven_home}/bin"
  _maven_prepend_path "${maven_home}/bin"
  export PATH
}

_maven_refresh_env
