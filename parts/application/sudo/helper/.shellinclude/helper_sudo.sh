#!/usr/bin/env zsh

# sudo_is_user_allowed [username] [--askpass]
# Prints 0 when the sudo true probe succeeds, otherwise 1; the function itself
# returns success after printing either result. An omitted or empty username
# selects the current user. Failure to resolve that user fails closed.
# Both user switches are noninteractive. By default no dialog is shown; a human
# caller may explicitly pass --askpass as the second argument to try an inner
# sudo -A after a failed probe, using existing sudo/askpass configuration.
# Askpass may show a password dialog; cancellation, missing configuration,
# authentication failure, or policy denial prints 1. Failure does not prove
# the user has no sudo permissions; success only probes sudo true and does not
# authorize another command. The Docker caller keeps the default; its later
# sudo docker command can still prompt and performs its own policy check.
function sudo_is_user_allowed() {
    local username="${1:-}"
    if [[ -z "$username" ]]; then
        username=$(whoami) || { echo 1; return; }
        [[ -n "$username" ]] || { echo 1; return; }
    fi
    if sudo -n -u "$username" sudo -n true 2>/dev/null; then
        echo 0
    elif [[ "${2:-}" == --askpass ]] && sudo -n -u "$username" sudo -A true 2>/dev/null; then
        echo 0
    else
        echo 1
    fi
}
