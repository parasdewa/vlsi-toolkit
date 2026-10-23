#!/usr/bin/env bash

ts_check_platform() {
    if [[ ! -r /etc/os-release ]]; then
        ts_error "Cannot identify the operating system; this setup helper supports Ubuntu 22.04, 24.04, and 26.04."
        return 1
    fi
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != ubuntu || ! "${VERSION_ID:-}" =~ ^(22\.04|24\.04|26\.04)$ ]]; then
        ts_error "Unsupported operating system: ${PRETTY_NAME:-unknown}. Supported releases: Ubuntu 22.04, 24.04, and 26.04."
        return 1
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        ts_error "apt-get is unavailable on this Ubuntu installation."
        return 1
    fi
    if grep -qi microsoft /proc/version 2>/dev/null; then
        ts_info "Platform: ${PRETTY_NAME} under WSL."
    else
        ts_info "Platform: ${PRETTY_NAME}."
    fi
}
