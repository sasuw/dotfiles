#Process find
psf() {
    ps -ef | grep -E "$1|PID" | grep -v " grep" | grep -E "$1|    " #last grep too keep color formatting
}

kill_process_with_string(){
    psf $1 | grep -v curl | awk '{print $2}' | tail -n1 | xargs kill
}

ps_print_java_processes(){
    local ps_filter="${1:-}"
    ps -ef | grep -e java | grep "${ps_filter}" | sed -E 's/-([A-Z])/\n-\1/g'
}