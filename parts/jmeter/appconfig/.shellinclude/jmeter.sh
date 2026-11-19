# JMETER_DIR is exported by rules/jmeter; fall back to JMETER_VERSION from
# common/zsh/.zshvars (the only pin) so the path is never hardcoded twice.
: "${JMETER_DIR:=/opt/apache-jmeter-${JMETER_VERSION}}"

[ -d "$JMETER_DIR" ] && export PATH="${JMETER_DIR}/bin:$PATH"
