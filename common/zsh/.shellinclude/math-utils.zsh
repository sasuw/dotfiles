rnd_generate_int () {
  local max_int=${1:-100}
  local min_int=${2:-1}
  echo $(( RANDOM % (max_int - min_int + 1) + min_int ))
}
