#!/usr/bin/env zsh

sort_no_header(){
	awk 'NR==1{print; next} {print | "sort"}'
}
