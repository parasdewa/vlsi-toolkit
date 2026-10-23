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
  local config_path="$2"
  shift 2

  if [[ ! -f "$PROJECT_ROOT/$config_path" ]]; then
    echo "Missing project manifest: $PROJECT_ROOT/$config_path" >&2
    echo "Create that TOML file with the settings for: vlsi $command_name" >&2
    return 2
  fi

  local cli
  cli="$(resolve_vlsi_cli)"
  cd "$PROJECT_ROOT"
  exec "$cli" "$command_name" --config "$config_path" "$@"
}
