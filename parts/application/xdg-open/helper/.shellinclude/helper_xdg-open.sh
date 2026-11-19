#!/usr/bin/env zsh

function xob(){
	nohup xdg-open "${1}" >/dev/null 2>&1 &
}


# xargs xdg-open
function xxo(){
	xargs -I{} xdg-open "{}"
}

# xargs xdg-open background
function xxob(){
	xargs -I{} nohup xdg-open "{}" >/dev/null 2>&1 &
}
