#!/usr/bin/env zsh

function xcat(){
    xargs -I{} cat "{}"
}
wcat(){
    which "$1" | xargs -I{} cat "{}" 
}
