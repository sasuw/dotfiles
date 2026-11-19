#!/usr/bin/env zsh

exiftool_print_image_date(){
  exiftool -ext jpg -ext jpeg -ext png -ext heic -p '$DateTimeOriginal $FileName' .
}