alias dsta='docker start $(docker ps -q -a)'
alias dsto='docker start $(docker ps -q -a)'
alias dpss="docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | column -t -s $'\t' | sort" #docker ps short
alias dps="docker ps"
alias dpsa="docker ps -a"

alias sd='sudo docker'
alias sdsto='sudo docker start $(docker ps -q -a)'
alias sdpss="sudo docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | column -t -s $'\t' | sort" #docker ps short
alias sdps="sudo docker ps"
alias sdpsa="sudo docker ps -a"

function docker-compose(){
	docker compose "$@"
}

docker_list_running_container_networks(){
	docker ps --format '{{.Names}} {{.Networks}}' | column -t -N Container,Network | awk 'NR==1{print; next} {print | "sort"}'
	if [ $(sudo_is_user_allowed) -eq 0 ]
	then
		sudo docker ps --format '{{.Names}} {{.Networks}}' | column -t -N Container,Network | awk 'NR==1{print; next} {print | "sort"}'
	fi
}