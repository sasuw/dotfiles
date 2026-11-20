function java_create_jars_for_main_classes(){

	if [ ! -d "src" ]; then
	  echo "No src directory found"
	  return 1
	fi
	fdfind --glob '*.jar' --max-depth 1 | xargs -I{} rm -f "{}"
	mvn clean compile
	rg -l -t java 'void main\(' </dev/null | xargs -I {} basename "{}" | cut -d '.' -f1 | xargs -I{} cp -r "target/classes" "target/classes_{}"
	rm -rf target/classes
	#rg -l -t java 'void main\(' | xargs -I {} basename "{}" | cut -d '.' -f1 | xargs -I{} echo 'jar cfe "{}.jar" $(fdfind "{}" src/main/java src/test/java | sed -e "s/\//\./g" | cut -d '.' -f 4- | rev | cut -d '.' -f2- | rev) -C target/classes_{} .' | zsh
	rg -l -t java 'void main\(' </dev/null | xargs -I {} basename "{}" | cut -d '.' -f1 | xargs -I{} echo 'jar cfe "{}.jar" $(fdfind "{}" src/main/java src/test/java | sed -e "s/\//\./g" | cut -d '.' -f 4- | rev | cut -d '.' -f2- | rev) -C target/classes_{} .' | tee /dev/tty | zsh
	mv *.jar target/
	echo -e '\nGenerated JAR files are in target/'
}

java_find_intellij_warnings_errors(){
  if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    printf 'Usage: java_find_intellij_warnings_errors REPORT_FILE_OR_DIRECTORY\n'
    return 0
  fi
  if (( $# != 1 )); then
    printf 'Usage: java_find_intellij_warnings_errors REPORT_FILE_OR_DIRECTORY\n' >&2
    return 2
  fi
  local report_input="$1"
  [[ "$report_input" == /* ]] || report_input="$PWD/$report_input"
  if [[ ! -e "$report_input" ]]; then
    printf 'Inspection report does not exist: %s\n' "$1" >&2
    return 1
  fi
	rg -l --null -i -e java -- "$report_input" | xargs -0 -I{} xmllint --xpath \
		'//problem[
		  normalize-space(language) = "JAVA"
		  and problem_class[
		    contains(concat(" ", normalize-space(@severity), " "), " WARNING ")
		    or contains(concat(" ", normalize-space(@severity), " "), " ERROR ")
		  ]
		]' "{}"
}
