#!/usr/bin/env zsh

##
# two or more line breaks > one line break
##
perl_collapse_linebreaks(){
  perl -0pe 's/\n{3,}/\n\n/g'
}