#!/usr/bin/env bash

ts_install_missing_packages() {
    local -a packages=("$@")
    local -a privilege=()
    if ((${#packages[@]} == 0)); then
        return 0
    fi
    if ((EUID != 0)); then
        if ! command -v sudo >/dev/null 2>&1; then
            ts_error "Installing missing packages requires root or sudo."
            return 1
        fi
        privilege=(sudo)
        ts_info "Requesting sudo authorization to install: ${packages[*]}"
        sudo -v || return 1
    fi
    ts_info "Refreshing apt package metadata (only because packages are missing)."
    if ! "${privilege[@]}" apt-get update 2>&1 | tee -a "$INSTALL_LOG"; then
        ts_error "apt-get update failed; see $INSTALL_LOG."
        return 1
    fi
    ts_info "Installing missing packages: ${packages[*]}"
    if ! "${privilege[@]}" apt-get install -y --no-install-recommends "${packages[@]}" 2>&1 | tee -a "$INSTALL_LOG"; then
        ts_error "Package installation failed; see $INSTALL_LOG."
        return 1
    fi
}
