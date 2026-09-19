#!/usr/bin/env bash

set -euo pipefail

BUILD_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"
MPV_TARGET_ARCH="${MPV_TARGET_ARCH:-$HOST_ARCH}"
case "$MPV_TARGET_ARCH" in
    aarch64|arm64|x86_64) ;;
    *)
        echo "Unsupported MPV_TARGET_ARCH: $MPV_TARGET_ARCH" >&2
        exit 1
        ;;
esac

if [ "$BUILD_OS" = "Darwin" ]; then
    export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$PROJECT_ROOT/vendor/libdovi"
INSTALL_PREFIX="${LIBDOVI_PREFIX:-${LOCAL_INSTALL_PREFIX:-$PROJECT_ROOT/install}}"
LIBDOVI_LIBDIR="${LIBDOVI_LIBDIR:-lib}"
LIBDOVI_JOBS="${LIBDOVI_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
LIBDOVI_TARGET="${LIBDOVI_TARGET:-}"

if [ "$BUILD_OS" = "Darwin" ]; then
    case "$MPV_TARGET_ARCH" in
        arm64)  LIBDOVI_TARGET="aarch64-apple-darwin" ;;
        x86_64) LIBDOVI_TARGET="x86_64-apple-darwin" ;;
    esac
fi

for tool in cargo cargo-cinstall; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "$tool not found in PATH" >&2
        exit 1
    fi
done

if [ ! -f "$SOURCE_DIR/dolby_vision/Cargo.toml" ]; then
    echo "Missing libdovi source: $SOURCE_DIR" >&2
    echo "Run: ./download.sh" >&2
    exit 1
fi

CARGO_ARGS=(
    --release
    --locked
    --jobs "$LIBDOVI_JOBS"
    --prefix "$INSTALL_PREFIX"
    --libdir "$LIBDOVI_LIBDIR"
)

if [ -n "$LIBDOVI_TARGET" ]; then
    CARGO_ARGS+=(--target "$LIBDOVI_TARGET")
fi

echo "Building libdovi"
echo "  source: $SOURCE_DIR/dolby_vision"
echo "  prefix: $INSTALL_PREFIX"
echo "  libdir: $LIBDOVI_LIBDIR"
echo "  jobs:   $LIBDOVI_JOBS"

pushd "$SOURCE_DIR/dolby_vision" >/dev/null
cargo cinstall "${CARGO_ARGS[@]}"
popd >/dev/null

for output in \
    "$INSTALL_PREFIX/include/libdovi/rpu_parser.h" \
    "$INSTALL_PREFIX/$LIBDOVI_LIBDIR/pkgconfig/dovi.pc"
do
    if [ ! -f "$output" ]; then
        echo "Expected output missing: $output" >&2
        exit 1
    fi
done

if ! compgen -G "$INSTALL_PREFIX/$LIBDOVI_LIBDIR/libdovi.*" >/dev/null; then
    echo "libdovi library was not installed under $INSTALL_PREFIX/$LIBDOVI_LIBDIR" >&2
    exit 1
fi

echo "libdovi build output ready in: $INSTALL_PREFIX"
