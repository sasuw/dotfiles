_java_prepend_path() {
  local path_entry="$1"

  [[ -d "${path_entry}" ]] || return 0
  case ":${PATH}:" in
    *:"${path_entry}":*) ;;
    *) PATH="${path_entry}:${PATH}" ;;
  esac
}

# Drop an inherited JAVA_HOME that no longer holds a JDK, e.g. the removed
# Homebrew /usr/local/opt/openjdk@25.
if [[ -n "${JAVA_HOME:-}" && ! -x "${JAVA_HOME}/bin/java" ]]; then
  unset JAVA_HOME
fi

case "${OS_CATEGORY:-}" in
  macos)
    # Prefer JDK 25, else the default JDK. -F fails instead of silently
    # returning another version.
    if [[ -z "${JAVA_HOME:-}" && -x /usr/libexec/java_home ]]; then
      java_home_candidate="$(/usr/libexec/java_home -F -v 25 2>/dev/null ||
        /usr/libexec/java_home -F 2>/dev/null || true)"
      if [[ -n "${java_home_candidate}" ]]; then
        JAVA_HOME="${java_home_candidate}"
        export JAVA_HOME
      fi
    fi
    ;;
  *)
    if [[ -d /usr/lib/jvm/java-25-openjdk-amd64 ]]; then
      JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64
      export JAVA_HOME
    fi
    ;;
esac

if [[ -n "${JAVA_HOME:-}" ]]; then
  _java_prepend_path "${JAVA_HOME}/bin"
  export PATH
fi

unset -f _java_prepend_path
unset java_home_candidate
