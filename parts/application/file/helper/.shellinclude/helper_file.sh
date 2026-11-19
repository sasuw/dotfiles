#!/usr/bin/env zsh


# Suggest an extension based on MIME type (tight allowlist = "reasonably secure")
#    Returns extension on stdout; non-zero if unknown/unsupported.
file_suggest_extension() {
  local f="$1"
  [[ -f "$f" ]] || return 1

  local mime
  mime=$(file --brief --mime-type -- "$f") || return 1

  case "$mime" in
    application/pdf)                         print -r -- "pdf" ;;

    image/png)                               print -r -- "png" ;;
    image/jpeg)                              print -r -- "jpg" ;;
    image/gif)                               print -r -- "gif" ;;
    image/webp)                              print -r -- "webp" ;;

    application/zip)                         print -r -- "zip" ;;
    application/x-7z-compressed)             print -r -- "7z" ;;
    application/x-rar|application/vnd.rar)   print -r -- "rar" ;;
    application/x-tar)                       print -r -- "tar" ;;
    application/gzip|application/x-gzip)     print -r -- "gz" ;;
    application/x-bzip2)                     print -r -- "bz2" ;;
    application/x-xz)                        print -r -- "xz" ;;

    audio/mpeg)                              print -r -- "mp3" ;;
    audio/flac)                              print -r -- "flac" ;;
    audio/wav|audio/x-wav)                   print -r -- "wav" ;;
    audio/ogg)                               print -r -- "ogg" ;;

    video/mp4)                               print -r -- "mp4" ;;
    video/x-matroska)                        print -r -- "mkv" ;;
    video/x-msvideo)                         print -r -- "avi" ;;
    video/quicktime)                         print -r -- "mov" ;;

    *) return 2 ;;
  esac
}

verify_file_extensions() {
  local dir="."
  local verbose=0

  while (( $# )); do
    case "$1" in
      -v|--verbose) verbose=1 ;;
      --) shift; break ;;
      -*) print -u2 -- "Unknown option: $1"; return 2 ;;
      *) dir="$1" ;;
    esac
    shift
  done

  [[ -d "$dir" ]] || { print -u2 -- "Not a directory: $dir"; return 1; }

  # MIME -> preferred extension (same "secure-ish" set as before)
  # (You can add mappings here as needed.)
  local -A mime2ext=(
    [application/pdf]=pdf

    [image/png]=png
    [image/jpeg]=jpg
    [image/gif]=gif
    [image/webp]=webp

    [application/zip]=zip
    [application/x-7z-compressed]=7z
    [application/x-rar]=rar
    [application/vnd.rar]=rar
    [application/x-tar]=tar
    [application/gzip]=gz
    [application/x-gzip]=gz
    [application/x-bzip2]=bz2
    [application/x-xz]=xz

    [audio/mpeg]=mp3
    [audio/flac]=flac
    [audio/wav]=wav
    [audio/x-wav]=wav
    [audio/ogg]=ogg

    [video/mp4]=mp4
    [video/x-matroska]=mkv
    [video/x-msvideo]=avi
    [video/quicktime]=mov
  )

  local -i suspicious=0 checked=0 skipped=0
  local f mime expected ext base

  # header (only if verbose)
  (( verbose )) && print -- "FILE|EXT|EXPECTED|MIME"

  # Search all regular files; ignore dotfiles/hidden by fd defaults + exclude
  while IFS= read -r -d '' f; do
    ((checked++))

    base="${f:t}"

    # ignore dotfiles explicitly (belt & suspenders)
    [[ "$base" == .* ]] && { ((skipped++)); continue; }

    mime=$(file --brief --mime-type -- "$f" 2>/dev/null) || { ((skipped++)); continue; }
    expected="${mime2ext[$mime]}"

    # Only verify types we consider "safe enough" to classify
    [[ -n "$expected" ]] || { ((skipped++)); continue; }

    # Extract current extension (lowercased). If none -> ext empty.
    if [[ "$base" == *.* ]]; then
      ext="${base##*.}"
      ext="${ext:l}"
    else
      ext=""
    fi

    # Accept a few common aliases (e.g. jpeg vs jpg, tif vs tiff if you add it, etc.)
    case "$expected:$ext" in
      jpg:jpeg|jpeg:jpg) continue ;;
    esac

    if [[ "$ext" != "$expected" ]]; then
      ((suspicious++))
      print -- "${f}|${ext:-<none>}|${expected}|${mime}"
    fi
  done < <(fd --type f --exclude '.*' -0 . "$dir")

  (( verbose )) && print -u2 -- "Done. checked=$checked suspicious=$suspicious skipped=$skipped (unknown mime types skipped)"
  (( suspicious == 0 ))
}
