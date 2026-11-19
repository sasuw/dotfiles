#!/usr/bin/env zsh

openssl_print_pkcs12_info(){
  local passphrase="${1}"
  local keystore_filepath="${2}"
  if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <passphrase> <keystore_filepath>"
    return 1
  fi
  openssl pkcs12 -passin "pass:${passphrase}" -in "${keystore_filepath}" -clcerts -nokeys -provider default -provider legacy -legacy | openssl x509 -in cert.pem -noout -subject -issuer -serial -dates -text  
}


openssl_get_pem_digest(){
  openssl x509 -in "${1}" -passin "pass:${2}" -pubkey -noout | openssl pkey -pubin -pubout -outform DER | openssl dgst -sha256
}

openssl_print_ec_public_point(){
  openssl pkey -in "${1}" -text -noout | sed -n '/pub:/,/ASN1 OID/p'
}

openssl_extract_private_key_from_keystore(){
  temp_dir=$(mktemp -d)
  temp_pem="${temp_dir}/tmp_priv.pem"
  keystore_file="${1}"
  openssl pkcs12 -in "${keystore_file}" -nocerts -out "${temp_pem}"
  echo "${temp_pem}"
}

openssl_get_ecdsa_public_key_from_private_key_pem_file(){
  local infile="${1}"
  local tmp_dir="$(mktemp -d)"
  local private_key_filename=$(basename "${infile}")
  local private_key_filename_no_suffix=$(echo ${private_key_filename} | rev | cut -d '.' -f2- | rev)
  local public_key_filename_no_suffix=$(echo ${private_key_filename_no_suffix} | sed -E 's|private|public|g')
  local key_public_ecdsa_filename="${public_key_filename_no_suffix}-ecdsa-sha2-nistp256.pem"
  local key_public_ecdsa_filepath="${tmp_dir}/${key_public_ecdsa_filename}"
  ssh-keygen -y -f "${infile}" > "${key_public_ecdsa_filepath}"
  echo "Created public key file ${key_public_ecdsa_filepath}"
  echo "Public key:"
  local ecdsa_public_key=$(cat $key_public_ecdsa_filepath)
  echo -e "\t${ecdsa_public_key}"
}

openssl_get_ecdsa_public_key_from_keystore(){
  local keystore_file="${1}"
  local private_key_file=$(openssl_extract_private_key_from_keystore ${keystore_file})
  echo "$(openssl_get_ecdsa_public_key_from_private_key_pem_file ${private_key_file})"
}

sshkeygen_print_key_infos(){
  local search_root_path="$1"
  fd . "$search_root_path" -t f -x sh -c '
    printf "\n%s\n" "$1"
    ssh-keygen -lf "$1" 2>/dev/null ||
    ssh-keygen -i -m RFC4716 -f "$1" 2>/dev/null | ssh-keygen -lf - 2>/dev/null ||
    echo "unrecognized key format"
  ' sh {}
}

sshkeygen_find_keys_and_print_sha256_fingerprint(){
  local search_term="$1"
  local search_root_path="${2:-.}"
  fd "$search_term" "$search_root_path" | sort | xargs -I{} zsh -c 'echo -n "{} | "; ssh-keygen -E sha256 -lf "{}" || true' _ {} | sort -t ':' -k2,2
}

