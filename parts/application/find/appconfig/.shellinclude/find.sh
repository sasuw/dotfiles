#Find with ending
fwe() {
    find . -iname "*.$1"
}

#Find with name
fwn() {
    find . -type d -name "target" -prune -false -o -iname "$1"
}

#Find with part
fwp() {
    find . -iname "*$1*"
}

find_cert_files_in_config() {
    find -type f | grep -v properties | grep -v '\.xml' | grep -v '\.bat' | grep -v '\.sh' | sort
}

#Finds FILE1 in DIR1 and gets its relative path to FILE2 in DIR2
function find_and_print_relative_path() {
    fdfind $FILE1 $DIR1 | head -n1 | xargs -I{} realpath --relative-to `fdfind $FILE2 $DIR2 | head -n1` "{}"
}

function find_dirs_in_root_recursive(){
    DIRNAME=$1
    fdfind ${DIRNAME} -E sys -E proc -E dev -E Dropbox -E snap -td / | grep -e "^.*\/${DIRNAME}\/$"
}

function find_large_files(){
    find . -type d \( -name node_modules -o -name Dropbox -o -name ".git"\ -o -name Windows \) -prune -o -type f -size +10G -print
}

function list_file_owners_in_dir(){
    DIR_PATH=$1
    find ${DIR_PATH} | sed 's/.*/"&"/' | xargs ls -l | awk '{print $3}' | grep -v '^$' | sort | uniq
}

function find_file_endings_recursively(){
    find . -type f | grep -o '\.[^./[:space:]]\+$' | sort | uniq -c
}

function find_keystore_and_certificate_files(){
    find . -type f -name '*.jceks' -o -name '*.jks' -o -name '*.ks' -o -name '*.pkcs12' -o -name '*.ppk' | sort
}

function find_latest_file_in_dir(){
    local dir_path="${1}"
    find "${dir_path}" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-
}

function find_empty_dirs() {
  local search_dir="${1:-.}"
  find "$search_dir" -type d -empty
}

function find_duplicate_lines_in_shell_script_files(){
    find . -name '*.*sh' -type f -exec cat {} + | sort | uniq -c | sort -nr | grep -v -E '\s*1' | grep -v -E '^\s+[0-9]{1,3}\s*.{1,6}\s*$' | trim | sort -k1 -h
}

function find_all_system_bins(){
    fdfind -p '.*/bin/.*' --type=file /
}

function find_ip_v4_addresses(){
    rg "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
    }


function find_ip_v4_addresses_sorted_and_counted(){
    find_ip_v4_addresses | grep -v 127 | grep -Po '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | sort | uniq -c
}

function find_system_files(){
    sudo fdfind "$1" /etc /run /usr /var
}

function find_file_in_jars(){
    local search_str="$1"
    find . -name "*.jar" -exec sh -c 'jar tf "$1" | grep -q "'${search_str}'" && echo "$1"' _ {} \;
}

find_files_with_no_ending() {
  find "${1:-.}" -type f ! -name "*.*"
}