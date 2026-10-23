#!/usr/bin/env bash

ts_info() { printf '[INFO] %s\n' "$*"; }
ts_warn() { printf '[WARN] %s\n' "$*" >&2; }
ts_error() { printf '[ERROR] %s\n' "$*" >&2; }
