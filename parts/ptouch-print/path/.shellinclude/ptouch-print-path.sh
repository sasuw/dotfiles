PTOUCH_PRINT_DIR="$HOME/bin/ptouch-print"

if [ -d "$PTOUCH_PRINT_DIR" ]
then
	export PATH="${PTOUCH_PRINT_DIR}/bin:$PATH"
    export MANPATH="$HOME/bin/ptouch-print/share/man:$MANPATH"
else
  return 1
fi
