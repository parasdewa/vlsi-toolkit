#!/usr/bin/env bash

MISSING_PACKAGES=()

ts_missing_packages() {
    MISSING_PACKAGES=()
    command -v git >/dev/null 2>&1 || MISSING_PACKAGES+=(git)
    if ! command -v tree >/dev/null 2>&1 || ! tree --version >/dev/null 2>&1; then
        MISSING_PACKAGES+=(tree)
    fi
    if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
        MISSING_PACKAGES+=(iverilog)
    fi
    command -v gtkwave >/dev/null 2>&1 || MISSING_PACKAGES+=(gtkwave)
    command -v yosys >/dev/null 2>&1 || MISSING_PACKAGES+=(yosys)
    if ! command -v python3 >/dev/null 2>&1; then
        MISSING_PACKAGES+=(python3)
    else
        local python_version python_major python_minor
        python_version="$(python3 --version 2>&1 | sed -nE 's/.* ([0-9]+)\.([0-9]+).*/\1 \2/p')"
        read -r python_major python_minor <<<"$python_version"
        if [[ "${python_major:-}" == 3 && "${python_minor:-}" == 10 ]] && ! python3 -c 'import tomli' >/dev/null 2>&1; then
            MISSING_PACKAGES+=(python3-tomli)
        fi
    fi
    if ! command -v g++ >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
        MISSING_PACKAGES+=(build-essential)
    fi
    for tool in autoconf flex bison help2man; do
        command -v "$tool" >/dev/null 2>&1 || MISSING_PACKAGES+=("$tool")
    done
    if ! ts_opensta_is_usable; then
        for package in cmake swig curl tcl-dev libeigen3-dev; do
            case "$package" in
                cmake) command -v cmake >/dev/null 2>&1 || MISSING_PACKAGES+=("$package") ;;
                swig) command -v swig >/dev/null 2>&1 || MISSING_PACKAGES+=("$package") ;;
                curl) command -v curl >/dev/null 2>&1 || MISSING_PACKAGES+=("$package") ;;
                tcl-dev) [[ -f /usr/include/tcl/tcl.h || -f /usr/include/tcl8.6/tcl.h ]] || MISSING_PACKAGES+=("$package") ;;
                libeigen3-dev) [[ -f /usr/include/eigen3/Eigen/Core ]] || MISSING_PACKAGES+=("$package") ;;
            esac
        done
    fi
    if ((${#MISSING_PACKAGES[@]})); then
        mapfile -t MISSING_PACKAGES < <(printf '%s\n' "${MISSING_PACKAGES[@]}" | sort -u)
    fi
}

ts_check_tools() {
    local failed=0 tool version
    for tool in git tree iverilog vvp gtkwave yosys python3 g++ make autoconf flex bison help2man sta; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            ts_error "Missing executable: $tool"
            failed=1
            continue
        fi
        case "$tool" in
            git) version="$(git --version 2>&1 | head -n 1)" ;;
            tree)
                if ! tree --version >/dev/null 2>&1; then
                    ts_error "tree is found at $(command -v tree), but it cannot run in this environment."
                    failed=1
                    continue
                fi
                version="$(tree --version 2>&1 | head -n 1)"
                ;;
            iverilog) version="$(iverilog -V 2>&1 | head -n 1)" ;;
            vvp) version="$(vvp -V 2>&1 | head -n 1)" ;;
            gtkwave) version="$(command -v gtkwave) (GUI launch not checked)" ;;
            yosys) version="$(yosys -V 2>&1 | head -n 1)" ;;
            python3) version="$(python3 --version 2>&1 | head -n 1)" ;;
            g++) version="$(g++ --version 2>&1 | head -n 1)" ;;
            make) version="$(make --version 2>&1 | head -n 1)" ;;
            autoconf) version="$(autoconf --version 2>&1 | head -n 1)" ;;
            flex) version="$(flex --version 2>&1 | head -n 1)" ;;
            bison) version="$(bison --version 2>&1 | head -n 1)" ;;
            help2man) version="$(help2man --version 2>&1 | head -n 1)" ;;
            sta) version="$(sta -version 2>&1 | head -n 1)" ;;
        esac
        printf '[PASS] %-10s %s\n' "$tool" "$version"
    done

    if command -v python3 >/dev/null 2>&1; then
        local py_version py_major py_minor
        py_version="$(python3 --version 2>&1 | sed -nE 's/.* ([0-9]+)\.([0-9]+).*/\1 \2/p')"
        read -r py_major py_minor <<<"$py_version"
        if [[ ! "${py_major:-}" =~ ^[0-9]+$ || ! "${py_minor:-}" =~ ^[0-9]+$ ]] || \
            ((py_major < 3 || (py_major == 3 && py_minor < 10))); then
            ts_error "Python 3.10 or newer is required by the toolkit CLI."
            failed=1
        elif ((py_major == 3 && py_minor == 10)) && ! python3 -c 'import tomli' >/dev/null 2>&1; then
            ts_error "Python 3.10 requires the Ubuntu python3-tomli package for TOML manifests."
            failed=1
        fi
    fi

    if command -v verilator >/dev/null 2>&1; then
        local version parsed major minor patch
        version="$(verilator --version 2>&1 | head -n 1)"
        printf '[PASS] %-10s %s\n' verilator "$version"
        parsed="$(sed -nE 's/.*Verilator ([0-9]+)\.([0-9]+)(\.([0-9]+))?.*/\1 \2 \4/p' <<<"$version")"
        read -r major minor patch <<<"$parsed"
        if [[ "${major:-}" =~ ^[0-9]+$ && "${minor:-}" =~ ^[0-9]+$ ]]; then
            major=$((10#$major))
            minor=$((10#$minor))
        fi
        if [[ -z "${major:-}" ]] || ((major < 5 || (major == 5 && minor < 52))); then
            ts_error "Verilator 5.052 or newer is required for this toolkit's verified UVM 2020.3.2 flow."
            failed=1
        fi
    else
        ts_error "Missing executable: verilator"
        failed=1
    fi
    return "$failed"
}
