get_env_or_secret() {
    local var_name="$1"
    local keyring_label="$2"

    # Check if the environment variable is already set
    if [[ -n "${(P)var_name}" ]]; then
        echo "${(P)var_name}"
        return 0
    fi

    # Check if secret-tool is available
    if (( $+commands[secret-tool] )); then
        local secret
        secret=$(secret-tool lookup "env" "$keyring_label" 2>/dev/null)
        
        if [[ -n "$secret" ]]; then
            export "$var_name"="$secret"
            echo "$secret"
            return 0
        fi
    fi

    # If neither method worked, print an error
    echo "Error: Variable '$var_name' is not set and could not be retrieved from the keyring." >&2
    return 1
}
