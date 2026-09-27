#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1
output=$(godot --headless --path . --script res://tests/run.gd 2>&1)
status=$?
echo "$output" | grep -v '^Godot Engine'
if grep -q 'SCRIPT ERROR' <<<"$output"; then
	echo "script errors during tests" >&2
	exit 1
fi
exit $status
