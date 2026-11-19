#!/usr/bin/env zsh

sed_bold_firstrow() {
  sed '1s/.*/\x1b[1m&\x1b[0m/'
}

sed_underline_firstrow () {
  sed '1s/.*/\x1b[4m&\x1b[0m/'
}

sed_declutter_java_stacktrace(){
  sed 's/)/)\n/g'
}

#Example usage
#   re=$(sed_escape_re 'a/b[c].*^$+(foo)|?')
#   rp=$(sed_escape_repl 'a/b&c\1')
# Use a non-/ delimiter to reduce escaping needs:
#   sed "s|$re|$rp|g" file

# Escape a literal string so it is safe to put into sed's *search* regex (BRE default).
# This makes the string match literally (no regex metacharacters).
sed_escape_re() {
  emulate -L zsh
  local s="$1"

  # Escape: \ . * [ ] ^ $ and also BRE/ERE operators just in case: ( ) { } + ? |
  # Also escape '/' because it's commonly the delimiter; harmless even if you use another delimiter.
  s=${s//\\/\\\\}
  s=${s//\//\\/}
  s=${s//./\\.}
  s=${s//\*/\\*}
  s=${s//\[/\\[}
  s=${s//\]/\\]}
  s=${s//^/\\^}
  s=${s//\$/\\$}
  s=${s//\(/\\(}
  s=${s//\)/\\)}
  s=${s//\{/\\{}
  s=${s//\}/\\}}
  s=${s//+/\\+}
  s=${s//\?/\\?}
  s=${s//|/\\|}
  print -r -- "$s"
}

# Escape a literal string so it is safe to put into sed's *replacement*.
# Only '\' and '&' are special in the replacement (plus delimiter if you use '/').
sed_escape_repl() {
  emulate -L zsh
  local s="$1"

  s=${s//\\/\\\\}   # literal backslash
  s=${s//&/\\&}     # literal ampersand
  s=${s//\//\\/}    # escape '/' delimiter (safe even if you later switch delimiters)
  print -r -- "$s"
}

# Convenience: print "escaped_regex<TAB>escaped_replacement"
sed_escape_both() {
  emulate -L zsh
  local in="$1"
  print -r -- "$(sed_escape_re "$in")\t$(sed_escape_repl "$in")"
}

#If you have a file with sed replacements, this reverses the search and replacment part for reverse replacement
sed_reverse_replacements_file(){
  sed -E 's|(s/)(.*?/)(.*/)(g)|\1\3\2\4|'
}

sed_remove_newlines(){
  sed -zE -e 's|\n||g' -e 's| +| |g' | trim
}

#Removes neewlines and also strings ' \ ' (because newlines are often preceeded with backslashes for pasting in shell)
sed_remove_newlines(){
  sed -zE -e 's|\n||g' -e 's| +| |g' | sed -E 's| \\ | |g' | trim
}

sed_normalize_ws_to_pipe() {
  sed -E 's/[[:space:]]{2,}/|/g'
}
