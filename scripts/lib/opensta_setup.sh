#!/usr/bin/env bash

OPENSTA_ROOT="${OPENSTA_ROOT:-${HOME}/opt/opensta}"
OPENSTA_VERSION="3.1.0"
OPENSTA_COMMIT="bdc4e054cb917e1b7058444829191838b302cccd"
CUDD_VERSION="3.0.0"
CUDD_URL="https://raw.githubusercontent.com/davidkebo/cudd/main/cudd_versions/cudd-3.0.0.tar.gz"
CUDD_SHA256="b8e966b4562c96a03e7fbea239729587d7b395d53cadcc39a7203b49cf7eeb69"

ts_opensta_activate_local() {
    local local_bin="$OPENSTA_ROOT/install/bin"
    if [[ -x "$local_bin/sta" ]]; then
        PATH="$local_bin:$PATH"
        export PATH
    fi
}

ts_opensta_is_usable() {
    local executable
    executable="$(command -v sta 2>/dev/null)" || return 1
    "$executable" -version >/dev/null 2>&1
}

ts_enable_opensta_shell_path() {
    local local_bin="$OPENSTA_ROOT/install/bin"
    local env_file="$OPENSTA_ROOT/opensta-env.sh"
    local bashrc="${HOME}/.bashrc"
    local quoted_env
    [[ -x "$local_bin/sta" ]] || return 0

    cat >"$env_file" <<'ENV'
#!/usr/bin/env bash
_opensta_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_opensta_bin="${_opensta_root}/install/bin"
case ":${PATH}:" in
    *":${_opensta_bin}:"*) ;;
    *) export PATH="${_opensta_bin}:${PATH}" ;;
esac
unset _opensta_root _opensta_bin
ENV
    chmod +x "$env_file"

    if [[ -f "$bashrc" ]] && ! grep -Fq 'opensta-env.sh' "$bashrc"; then
        printf -v quoted_env '%q' "$env_file"
        cat >>"$bashrc" <<EOF

# OpenSTA installed by the VLSI toolkit
if [[ -f $quoted_env ]]; then
    source $quoted_env
fi
EOF
        ts_info "Added the OpenSTA environment helper to $bashrc for future Bash shells."
    fi
}

ts_prepare_opensta() {
    ts_opensta_activate_local
    if ts_opensta_is_usable; then
        ts_enable_opensta_shell_path
        ts_info "OpenSTA is available: $(command -v sta) ($(sta -version 2>&1 | head -n 1))."
        return 0
    fi

    local stage cudd_prefix install_prefix env_file
    install_prefix="$OPENSTA_ROOT/install"
    cudd_prefix="$OPENSTA_ROOT/deps/cudd-$CUDD_VERSION"
    mkdir -p "$OPENSTA_ROOT" "$OPENSTA_ROOT/deps"
    stage="$(mktemp -d "${TMPDIR:-/tmp}/vlsi-opensta-build.XXXXXX")" || return 1
    ts_info "Building OpenSTA $OPENSTA_VERSION with one job under $OPENSTA_ROOT."

    if ! (
        set -euo pipefail
        git init "$stage/OpenSTA"
        git -C "$stage/OpenSTA" fetch --depth 1 \
            https://github.com/parallaxsw/OpenSTA.git "$OPENSTA_COMMIT"
        git -C "$stage/OpenSTA" checkout --detach FETCH_HEAD
        curl --fail --location --retry 2 --output "$stage/cudd-$CUDD_VERSION.tar.gz" "$CUDD_URL"
        printf '%s  %s\n' "$CUDD_SHA256" "$stage/cudd-$CUDD_VERSION.tar.gz" | sha256sum --check --status
        tar -xzf "$stage/cudd-$CUDD_VERSION.tar.gz" -C "$stage"
        cd "$stage/cudd-$CUDD_VERSION"
        ./configure --prefix="$cudd_prefix"
        make -j1
        make install
        cmake -S "$stage/OpenSTA" -B "$stage/OpenSTA/build" \
            -DCUDD_DIR="$cudd_prefix" \
            -DCMAKE_INSTALL_PREFIX="$install_prefix" \
            -DUSE_TCL_READLINE=OFF \
            -DCMAKE_BUILD_TYPE=Release
        cmake --build "$stage/OpenSTA/build" --parallel 1
        cmake --install "$stage/OpenSTA/build"
    ) >"$stage/build.log" 2>&1; then
        cat "$stage/build.log" | tee -a "$INSTALL_LOG"
        rm -rf -- "$stage"
        ts_error "OpenSTA build failed; see $INSTALL_LOG."
        return 1
    fi

    cat "$stage/build.log" | tee -a "$INSTALL_LOG"
    rm -rf -- "$stage"
    env_file="$OPENSTA_ROOT/opensta-env.sh"
    ts_enable_opensta_shell_path
    ts_opensta_activate_local
    if ! ts_opensta_is_usable; then
        ts_error "OpenSTA was built but sta -version did not succeed."
        return 1
    fi
    ts_info "Installed OpenSTA $(sta -version) at $install_prefix/bin/sta."
}
