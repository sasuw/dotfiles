jq_find_attr_value_path() {
  local attr_value_to_find="${1}"
  local file_path="${2}"

  jq --arg attr_value_to_find "${attr_value_to_find}" -r '
    paths(scalars) as $p
    | select(getpath($p) == $attr_value_to_find)
    | [$p | map(
        if type == "number" then
          "[" + tostring + "]"
        else
          "." + .
        end
      ) | join("") ]
    | .[0]
  ' "${file_path}"
}

jq_get_parent_object_with_field_name_and_value(){
  local attr_name_to_find="${1}"
  local attr_value_to_find="${2}"
  local file_path="${3}"

  local jq_query=".[] | select(.${attr_name_to_find} == \"${attr_value_to_find}\")"
  #echo $jq_query
  jq "${jq_query}" "${file_path}"
}


function json_array_to_table(){
     jq -r '(.[0] | ([keys[] | .] |(., map(length*"-")))), (.[] | ([keys[] as $k | .[$k]])) | @tsv' | column -t -s $'\t' 2>/dev/null
}

function json_array_to_table2() {
    jq -r '
        (.[0] | keys_unsorted) as $keys |
        ([$keys[] | tostring] | (., map(length*"-"))),
        (.[] | select(. != null) | [$keys[] as $k | .[$k] | tostring]) |
        @tsv
    ' | column -t -s $'\t' 2>/dev/null
}


cleanjson() {
  tr -d '\000-\031' | jq .
}
