#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export VCPKG_TARGET_TRIPLET="${VCPKG_TARGET_TRIPLET:-x64-mingw-mp}"

if [ -z "${VCPKG_HOST_TRIPLET:-}" ]; then
    case "$(uname -m)" in
        x86_64) export VCPKG_HOST_TRIPLET="x64-linux" ;;
        aarch64|arm64) export VCPKG_HOST_TRIPLET="arm64-linux" ;;
        *)
            echo "Unsupported Linux host architecture for default VCPKG_HOST_TRIPLET: $(uname -m)" >&2
            echo "Set VCPKG_HOST_TRIPLET explicitly." >&2
            exit 1
            ;;
    esac
fi

exec "$PROJECT_ROOT/install-vcpkg-deps.sh" "$@"
