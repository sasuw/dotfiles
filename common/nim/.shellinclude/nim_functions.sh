function get_nimble_version() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: get_nimble_version <directory>"
        return 1
    fi

    local dir_path=$1

    if [[ ! -d $dir_path ]]; then
        echo "Error: '$dir_path' is not a valid directory."
        return 1
    fi

    local nimble_files=($dir_path/*.nimble)
    local num_files=${#nimble_files[@]}

    if (( num_files == 0 )); then
        echo "Error: No .nimble file found in the directory '$dir_path'."
        return 1
    elif (( num_files > 1 )); then
        echo "Error: Multiple .nimble files found in the directory '$dir_path'."
        return 1
    fi

    local nimble_file=${nimble_files[1]}
    local nimble_version=$(awk -F'"' '/version/{split($2, a, /\./); printf "%s \"%d.%d.%d\"\n", $1, a[1], a[2], a[3]}' "${nimble_file}" | rev | cut -d' ' -f1 | rev | cut -d'"' -f2)
    echo $nimble_version
}

function get_nimble_description() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: get_nimble_description <nimble_file>"
        return 1
    fi

    local nimble_file=$1

    if [[ ! -f $nimble_file ]]; then
        echo "Error: File '$nimble_file' does not exist."
        return 1
    fi

    local description=$(awk -F'"' '/description/{print $2}' "$nimble_file")

    if [[ -z $description ]]; then
        echo "Error: No description field found in the file '$nimble_file'."
        return 1
    fi

    echo "$description"
}