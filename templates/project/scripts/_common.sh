#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_vlsi_cli() {
  if [[ -n "${VLSI_CLI:-}" ]]; then
    if [[ -x "$VLSI_CLI" ]]; then
      printf '%s\n' "$VLSI_CLI"
      return 0
    fi
    echo "VLSI_CLI is set but is not executable: $VLSI_CLI" >&2
    return 2
  fi

  if command -v vlsi >/dev/null 2>&1; then
    command -v vlsi
    return 0
  fi

  local sibling_toolkit="$PROJECT_ROOT/../vlsi-toolkit/vlsi"
  if [[ -x "$sibling_toolkit" ]]; then
    printf '%s\n' "$sibling_toolkit"
    return 0
  fi

  echo "Cannot find the vlsi command. Add it to PATH, set VLSI_CLI, or place this project beside vlsi-toolkit." >&2
  return 127
}

run_with_config() {
  local command_name="$1"
  local default_config="$2"
  shift 2

  local config_path="$default_config"
  if [[ "${1:-}" == "--config" ]]; then
    if [[ "$#" -lt 2 || -z "${2:-}" ]]; then
      echo "Usage: $0 [MANIFEST.toml | --config MANIFEST.toml] [vlsi options]" >&2
      return 2
    fi
    config_path="$2"
    shift 2
  elif [[ "${1:-}" == *.toml ]]; then
    config_path="$1"
    shift
  fi

  local config_file
  if [[ "$config_path" == /* ]]; then
    config_file="$config_path"
  else
    config_file="$PROJECT_ROOT/$config_path"
  fi

  if [[ ! -f "$config_file" ]]; then
    echo "Missing project manifest: $config_file" >&2
    echo "Create that TOML file with the settings for: vlsi $command_name" >&2
    return 2
  fi

  local cli
  cli="$(resolve_vlsi_cli)"
  cd "$PROJECT_ROOT"
  exec "$cli" "$command_name" --config "$config_file" "$@"
}
