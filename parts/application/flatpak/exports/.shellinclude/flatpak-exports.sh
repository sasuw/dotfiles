export "PATH=${PATH}:/var/lib/flatpak/exports/share"
export "PATH=${PATH}:${HOME}/.local/share/flatpak/exports/share"
# A set XDG_DATA_DIRS replaces the XDG default (/usr/local/share:/usr/share),
# so start from that default when it is unset or empty (SSH, agent shells).
# Without /usr/share, gsettings finds no schemas and GIO detects no MIME types.
# Skip when the Flatpak directory is already listed (GNOME session, nested shells).
case ":${XDG_DATA_DIRS:-}:" in
  *":/var/lib/flatpak/exports/share:"*) ;;
  *) export "XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share" ;;
esac
