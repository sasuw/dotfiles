#!/usr/bin/env zsh

function yq_flatten_yaml_file_to_properties(){
	local filepath="${1}"
	yq -o=json . "${filepath}" | jq -r 'paths(scalars) as $p | [($p | join(".")), getpath($p)] | "\(.[0])=\(.[1])"'
}