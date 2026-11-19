#Useful when e.g. Maven build fails with `gpg: signing failed: No pinentry`
function gpg_test_and_activate(){
	echo "test" | gpg --clearsign
}

# https://github.com/bfrg/gpg-guide

function gpg_list_my_public_keys(){
	gpg --list-key | grep -i -B2 -A2 "$(whoami)"
}

function gpg_list_my_sigs(){
	gpg --list-sigs | grep -i -B2 -A3 "$(whoami)"
}

function gpg_my_fingerprint(){
	gpg --fingerprint | grep -i -B2 -A1 "$(whoami)"
}

function gpg_list_my_secret_keys(){
	gpg --list-secret-keys | grep -i -B2 -A1 "$(whoami)"
}