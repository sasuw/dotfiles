alias bat='batcat'

function xbat(){
    xargs -I{} batcat "{}"
}
wbat(){
    which "$1" | xargs -I{} batcat "{}" 
}
