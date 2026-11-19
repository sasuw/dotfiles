#!/usr/bin/env zsh


#Unzips file to a directory with the same name, minus file ending. As third argument a password can be given.
#The directory for unzipping is per default the same diretory where the zip is unless given in the second argument.
#Example: unzip_file_to_dir_with_filename_minus_zip file.zip . password creates a directory ./file and unzips the contents
#of file.zip there, decrypting with password "password".
function unzip_file_to_dir_with_filename_minus_zip(){
	local zip_file_path_arg=$1
	local zip_file_path="$(realpath ${zip_file_path_arg})"
	local zip_file_name_stripped=$(basename "${zip_file_path_arg}" | rev | cut -d '.' -f2- | rev)

	local unzip_dir
	if [[ -n $2 ]]
	then
		unzip_dir="${2}/${zip_file_name_stripped}"
	else
		unzip_dir=${zip_file_path_arg}
	fi

	#echo "zip_file_path_arg: $zip_file_path_arg"
	#echo "zip_file_path: $zip_file_path"
	#echo "unzip_dir: $unzip_dir"

	mkdir -p "${unzip_dir}"

	if [[ -n $3 ]]
	then
		unzip -P "${3}" -d "${unzip_dir}" "${zip_file_path}"
	else
		unzip -d "${unzip_dir}" "${zip_file_path}"
	fi
}
