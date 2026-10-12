#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${1:-godot}"
QA_HOME="$(mktemp -d)"
trap 'rm -rf "$QA_HOME"' EXIT
export HOME="$QA_HOME/home" XDG_CONFIG_HOME="$QA_HOME/config" XDG_DATA_HOME="$QA_HOME/data" XDG_CACHE_HOME="$QA_HOME/cache"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
"$GODOT" --headless --editor --path "$PROJECT_DIR" --import
"$GODOT" --headless --path "$PROJECT_DIR" --script res://tests/regression.gd
"$GODOT" --headless --path "$PROJECT_DIR" --quit-after 120
