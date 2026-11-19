keytool_convert_jceks_to_p12(){
	local srckeystore=$1
	local destkeystore=$2
	if [ "$#" -ne 2 ]; then
	  echo "Usage: $0 <srckeystore> <destkeystore>"
	  return 1
	fi

	keytool -importkeystore -srckeystore "${srckeystore}" -destkeystore "${destkeystore}" -deststoretype pkcs12
}

keytool_print_pkcs12_info(){
	if [ "$#" -ne 2 ]; then
	  echo "Usage: $0 <passphrase> <keystore_filepath>"
	  return 1
	fi
	local passphrase="${1}"
	local keystore_filepath=$(realpath "${2}")
	keytool -list -v -keystore "${keystore_filepath}" -storetype PKCS12 -storepass "${passphrase}"
}

