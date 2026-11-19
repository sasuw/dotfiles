alias sm='smerge'
function sm.(){
	local git_root_dir
	git_root_dir="$(git rev-parse --show-toplevel)"
	smerge "${git_root_dir}"
}

alias smn='smerge'
function smn.(){
	local git_root_dir
	git_root_dir="$(git rev-parse --show-toplevel)"
	smerge --launch-or-new-window "${git_root_dir}"
}
