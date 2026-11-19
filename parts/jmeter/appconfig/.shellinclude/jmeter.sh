# Use the same installation root and .zshversions pin as rules/jmeter.
: "${JMETER_DIR:=${JMETER_INSTALL_ROOT:-/opt}/apache-jmeter-${JMETER_VERSION}}"

[ -d "$JMETER_DIR" ] && export PATH="${JMETER_DIR}/bin:$PATH"
