function curlt(){
	curl -s --write-out '%{time_total}' -o /dev/null "$@"
}

function curl_find_from_history(){
	hgg wysiwys curl "$@" | cut -d ' ' -f3- | grep '^curl.*' | sort | uniq
}
