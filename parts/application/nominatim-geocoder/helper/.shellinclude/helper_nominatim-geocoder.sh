#!/usr/bin/env zsh

nominatim_geocoder_coordinates_from_location(){
	nominatim-geocoder "${1}" | grep -v Location | grep -o -E '[0-9]{1,3}\.[0-9]{1,7}' | paste -d' ' - - | tr ' ' ','
}
