#!/usr/bin/env bash

ts_verilator_is_supported() {
    local version parsed major minor patch
    command -v verilator >/dev/null 2>&1 || return 1
    version="$(verilator --version 2>&1 | head -n 1)"
    parsed="$(sed -nE 's/.*Verilator ([0-9]+)\.([0-9]+)(\.([0-9]+))?.*/\1 \2 \4/p' <<<"$version")"
    read -r major minor patch <<<"$parsed"
    if [[ "${major:-}" =~ ^[0-9]+$ && "${minor:-}" =~ ^[0-9]+$ ]]; then
        major=$((10#$major))
        minor=$((10#$minor))
    fi
    [[ -n "${major:-}" ]] && ((major > 5 || (major == 5 && minor >= 52)))
}

ts_prepare_verilator_uvm() {
    local opt_root source_dir prefix env_file existing_bin existing_root use_local
    use_local=0
    opt_root="${HOME:?}/opt/vlsi-toolkit"
    source_dir="${VLSI_VERILATOR_SOURCE_DIR:-$opt_root/verilator-5.052-src}"
    prefix="${VLSI_VERILATOR_PREFIX:-${HOME:?}/opt/verilator-5.052}"
    env_file="$opt_root/verilator-env.sh"

    if ! ts_verilator_is_supported && [[ -x "$prefix/bin/verilator" ]]; then
        export PATH="$prefix/bin:$PATH"
        export VERILATOR_ROOT="$prefix/share/verilator"
        use_local=1
    fi
    if ts_verilator_is_supported; then
        ts_info "Keeping existing Verilator: $(command -v verilator) ($(verilator --version | head -n 1))."
    else
        if [[ -e "$source_dir" && ! -f "$source_dir/test_regress/t/uvm/uvm_pkg_all_v2020_3_2_nodpi.svh" ]]; then
            ts_error "Verilator source directory exists but does not contain the expected UVM package: $source_dir"
            ts_error "Set VLSI_VERILATOR_SOURCE_DIR to a clean Verilator v5.052 checkout, or move the incomplete directory aside."
            return 1
        fi
        if [[ ! -d "$source_dir/.git" ]]; then
            if [[ -e "$source_dir" ]]; then
                ts_error "Refusing to overwrite existing path: $source_dir"
                return 1
            fi
            mkdir -p "$(dirname -- "$source_dir")"
            ts_info "Fetching Verilator v5.052 source into $source_dir."
            git clone --depth 1 --branch v5.052 https://github.com/verilator/verilator.git "$source_dir" 2>&1 | tee -a "$INSTALL_LOG" || return 1
        fi
        if [[ ! -f "$source_dir/configure.ac" || ! -f "$source_dir/test_regress/t/uvm/uvm_pkg_all_v2020_3_2_nodpi.svh" ]]; then
            ts_error "The selected source directory is not a complete Verilator v5.052 checkout: $source_dir"
            return 1
        fi
        mkdir -p "$(dirname -- "$prefix")" "$opt_root"
        ts_info "Building Verilator v5.052 into $prefix with one job. This can take several minutes."
        if ! (cd "$source_dir" && autoconf && ./configure --prefix="$prefix" && make -j1 && make install) 2>&1 | tee -a "$INSTALL_LOG"; then
            ts_error "Verilator source build failed; see $INSTALL_LOG. Existing Verilator installations were not removed."
            return 1
        fi
        export PATH="$prefix/bin:$PATH"
        export VERILATOR_ROOT="$prefix/share/verilator"
        use_local=1
        ts_info "Installed isolated Verilator: $prefix/bin/verilator"
    fi

    existing_bin="$(command -v verilator 2>/dev/null || true)"
    if [[ -n "$existing_bin" ]]; then
        existing_root="$(cd -- "$(dirname -- "$(readlink -f "$existing_bin")")/.." && pwd)"
        if [[ -f "$existing_root/test_regress/t/uvm/uvm_pkg_all_v2020_3_2_nodpi.svh" ]]; then
            export VERILATOR_UVM_DIR="$existing_root/test_regress/t/uvm"
        fi
    fi

    if [[ -z "${VERILATOR_UVM_DIR:-}" || ! -f "$VERILATOR_UVM_DIR/uvm_pkg_all_v2020_3_2_nodpi.svh" ]]; then
        if [[ ! -f "$source_dir/test_regress/t/uvm/uvm_pkg_all_v2020_3_2_nodpi.svh" ]]; then
            if [[ -e "$source_dir" ]]; then
                ts_error "Refusing to overwrite incomplete Verilator source path: $source_dir"
                return 1
            fi
            mkdir -p "$(dirname -- "$source_dir")"
            ts_info "Fetching the pinned Verilator v5.052 UVM test package."
            git clone --depth 1 --branch v5.052 https://github.com/verilator/verilator.git "$source_dir" 2>&1 | tee -a "$INSTALL_LOG" || return 1
        fi
        export VERILATOR_UVM_DIR="$source_dir/test_regress/t/uvm"
    fi
    if [[ -n "${VERILATOR_UVM_DIR:-}" && -f "$VERILATOR_UVM_DIR/uvm_pkg_all_v2020_3_2_nodpi.svh" ]]; then
        mkdir -p "$opt_root"
        if ((use_local)); then
            cat >"$env_file" <<EOF
# Source this file to select the toolkit's isolated Verilator and UVM package.
export PATH="$prefix/bin:\$PATH"
export VERILATOR_ROOT="$prefix/share/verilator"
export VERILATOR_UVM_DIR="$VERILATOR_UVM_DIR"
EOF
        else
            cat >"$env_file" <<EOF
# Source this file to select the UVM package for the existing Verilator.
export VERILATOR_UVM_DIR="$VERILATOR_UVM_DIR"
EOF
        fi
        ts_info "UVM package: $VERILATOR_UVM_DIR"
        ts_info "For future shells, run: source $env_file"
        return 0
    fi
    ts_error "Could not find a Verilator UVM 2020.3.2 source package after setup."
    ts_error "Set VERILATOR_UVM_DIR or VLSI_VERILATOR_SOURCE_DIR and rerun the setup."
    return 1
}
