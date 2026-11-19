#!/usr/bin/env zsh

function ln_hardlink_files_in_dir(){
	local dir_to_link="${1}"
	for file in "${dir_to_link}"/*; do ln $file $(basename $file); done
	echo "Done"
}