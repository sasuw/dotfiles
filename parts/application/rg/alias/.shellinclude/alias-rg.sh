alias rg.='rg -.'
alias rg.="rg -. --sort=path"
alias rgi='rg -i --sort=path'
alias rgi.='rg -. -i --sort=path'
alias rgl="rg -l --sort=path"
alias rgl.="rg -l -. --sort=path"
alias rgli='rg -l -i --sort=path'
alias rgli.='rg -l -i -. --sort=path'
alias rglne="rgl -. --glob '!*emacs*'" #no emacs
alias rgne="rg -. --glob '!*emacs*'" #no emacs
alias rgnmd="rg --glob '!*.md' --sort=path" #no markdown
alias rgnj="rg -i --glob '!*emacs*' --glob '!*test*' --glob '!*.htm*' --glob '!*.hpp*' --glob '!*.cpp*' --glob '!*.encrypted*' --glob '!*.json' --glob '!*.min.js' --glob '!*.svg' --glob '!*template*' --glob '!*.map' --glob '!*.css' --glob '!*.csv' --glob '!*.md' --glob '!*.vue' --glob '!*mock*' --glob '!*Test*' --glob '!package*.json' --glob '!*postman*' --glob '!*jmeter*' --glob '!*.ipynb' --sort=path"
alias rgnjl="rgnj -l --sort=path"
