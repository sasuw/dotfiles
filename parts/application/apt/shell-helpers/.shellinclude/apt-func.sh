function acs() {
    local cmd="apt-cache search ${1}"
    shift
    for term in "$@"; do
        cmd="$cmd | grep -i \"${(q)term}\""
    done
    eval "$cmd"
}

function apts(){
	local pkg_name="${1}"
	apt show "${pkg_name}"
}

function apti(){
    local pkg_name="${1}"
    apt info "${pkg_name}"
}