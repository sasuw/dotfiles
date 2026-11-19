qpdf_show_signature_fields(){
  qpdf "${1}" --json | jq '.. | objects | select(has("fields")) | .fields[] | select(.fieldtype | contains("Sig"))'
}
