#!/usr/bin/env zsh

htmldecode() {
    python3 -c 'import html,sys; sys.stdout.write(html.unescape(sys.stdin.read()))'
}

# Decode percent escapes from one argument, or stdin when no argument is given.
urldecode() {
  if (( $# > 1 )); then
    printf '%s\n' 'Usage: urldecode [TEXT] (otherwise reads stdin)' >&2
    return 2
  fi
  python3 -c 'import sys; from urllib.parse import unquote; sys.stdout.write(unquote(sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()))' "$@"
}
