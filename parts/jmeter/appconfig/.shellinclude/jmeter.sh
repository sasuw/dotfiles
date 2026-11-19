# JMETER_DIR is exported by rules/jmeter; fall back to the version from
# .zshvars so the path is never hardcoded in two places.
: "${JMETER_DIR:=/opt/apache-jmeter-${JMETER_VERSION}}"

[ -d "$JMETER_DIR" ] && export PATH="${JMETER_DIR}/bin:$PATH"
