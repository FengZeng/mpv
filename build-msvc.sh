#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="$PROJECT_ROOT/build-msvc.ps1"

if [ ! -f "$PS_SCRIPT" ]; then
    echo "Missing script: $PS_SCRIPT" >&2
    exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "$@"
elif command -v powershell >/dev/null 2>&1; then
    exec powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "$@"
else
    echo "Neither pwsh nor powershell is available in PATH." >&2
    exit 1
fi
