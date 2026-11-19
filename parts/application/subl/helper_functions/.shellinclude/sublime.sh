#findFileAndSublime
ffas() {
    # Use fdfind to search for files and count the number of lines/files found
    local files_found=$(fdfind "$1" | wc -l)
    
    # Check if the number of found files is greater than 10
    if [ "$files_found" -gt 10 ]; then
        echo "Found $files_found files. Do you want to open all? (y/n)"
        read -r confirm
        if [ "$confirm" = "y" ]; then
            fdfind "$1" -tf | xargs subl
        else
            echo "Operation cancelled."
        fi
    else
        # If 10 or fewer files are found, open them directly
        fdfind "$1" -tf | xargs subl
    fi
}

ffas.() {
    # Use fdfind to search for files and count the number of lines/files found
    local files_found=$(fdfind "$1" | wc -l)
    
    # Check if the number of found files is greater than 10
    if [ "$files_found" -gt 10 ]; then
        echo "Found $files_found files. Do you want to open all? (y/n)"
        read -r confirm
        if [ "$confirm" = "y" ]; then
            fdfind "$1" -tf | xargs subl
        else
            echo "Operation cancelled."
        fi
    else
        # If 10 or fewer files are found, open them directly
        fdfind -HI "$1" -tf | xargs subl
    fi
}

#xargs sublime
function xs(){
    xargs -I{} subl "{}"
}

#xargs sublime first
function xsf(){
    head -n1 $1 | xargs -I{} subl "{}"
}

#xargs sublime last
function xsl(){
    tail -n1 $1 | xargs -I{} subl "{}"
}

#xargs sublime nth line
function xsn(){
    local nth="${1:-1}"
    head -n "${nth}" | tail -n1 | xargs -I{} subl "{}"
}

alias sl='subl'
alias sln='subl --launch-or-new-window'