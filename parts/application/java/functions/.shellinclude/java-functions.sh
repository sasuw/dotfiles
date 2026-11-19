#Java find public methods in class with name or part of name
javafpm() {
  fwp $1 | grep java | xargs cat | grep public | grep -v ';' | grep -v 'class' | sort
} 

print_war_jar_manifest() {
    unzip -p $1 META-INF/MANIFEST.MF | head -n 5
}

java_comment_out_line_with_match() {
  local pattern_to_match="${1}"
  rgl "^\s*${pattern_to_match}" | xargs sed -i "s/^\s*${pattern_to_match}/\/\/&/"
}

java_decompile(){
  local class_file="${1}"
  java -jar ~/bin/cfr-0.152.jar "${class_file}"
}

function java_find_field(){
    rg -i "(private|public|byte|short|int|long|float|double|char|String|boolean).*$1;" | grep java | cut -d ":" -f1 | rev | cut -d "/" -f1 | rev | sort | uniq -c | column --table --table-columns COUNT,"JAVA CLASS"
}
