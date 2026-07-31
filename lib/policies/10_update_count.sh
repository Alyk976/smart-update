#!/usr/bin/env bash

#!/usr/bin/env bash

policy_run() {

    logger_info "Policy: update_count"

    if ((${#UPDATE_PACKAGES[@]} > MAX_UPDATE_COUNT)); then

        POLICY_RESULT="BLOCK"
        POLICY_REASON="${#UPDATE_PACKAGES[@]} mises à jour détectées ; limite autorisée : ${MAX_UPDATE_COUNT}."

        return
    fi

    POLICY_RESULT="ALLOW"
    POLICY_REASON="Nombre de mises à jour dans la limite autorisée."
}
