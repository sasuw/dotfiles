#docker ps short
function dpss(){
	docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | column -t -s $'\t' | sort
}

function dstartall(){
	docker start $(docker ps -q -a)
}

function dstopall(){
	docker stop $(docker ps -q -a)
}

function dlf(){
	local container="${1}"
	docker logs -f "${container}"
}

function docker_az4_start(){
	docker run -it -d --name azcli-ipv4 --sysctl net.ipv6.conf.all.disable_ipv6=1 mcr.microsoft.com/azure-cli
}

function docker_az4_exec_old(){
	local cmd="${@}"
	local az_cmd="az ${cmd}"
	echo "Executing az command: ${az_cmd}"
	docker exec azcli-ipv4 bash -c "${az_cmd}"
}

docker_az4_exec() {
  docker exec azcli-ipv4 az "$@"
}

function docker_az4_exec_interactive(){
	local cmd="${@}"
	local az_cmd="az ${cmd}"
	echo "Executing az command: ${az_cmd}"
	docker exec -i azcli-ipv4 bash -c "${az_cmd}"
}

function docker_az4_exec_login(){
	docker_az4_exec_interactive login --allow-no-subscriptions --use-device-code
}

alias az4='docker_az4_exec'

function dr_swagger(){
	local port=${1:-80}
	docker run -p $port:8080 -e SWAGGER_JSON=/app/openapi.yaml -v $PWD/:/app swaggerapi/swagger-ui
}
