#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$PROJECT_ROOT/vendor"
MPV_DIR="$VENDOR_DIR/mpv"
BUILD_DIR_NAME="${MPV_BUILD_DIR:-build-mingw64}"
BUILD_DIR="$MPV_DIR/$BUILD_DIR_NAME"
VCPKG_INSTALLED_DIR="${VCPKG_INSTALLED_DIR:-$PROJECT_ROOT/vcpkg_installed}"
VCPKG_TARGET_TRIPLET="${VCPKG_TARGET_TRIPLET:-x64-mingw-mp}"
MPV_WIN32_WINNT="${MPV_WIN32_WINNT:-0x0601}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$PROJECT_ROOT/.cache}"

if [ ! -d "$MPV_DIR" ]; then
    echo "Missing mpv source: $MPV_DIR" >&2
    echo "Run: ./download.sh" >&2
    exit 1
fi

for tool in meson ninja pkg-config x86_64-w64-mingw32-gcc x86_64-w64-mingw32-g++ x86_64-w64-mingw32-windres; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "$tool not found in PATH" >&2
        exit 1
    fi
done

if [[ "$VCPKG_TARGET_TRIPLET" == *-static ]]; then
    VCPKG_STATIC_TRIPLET="$VCPKG_TARGET_TRIPLET"
    VCPKG_DYNAMIC_TRIPLET="${VCPKG_TARGET_TRIPLET%-static}"
    if [ ! -d "$VCPKG_INSTALLED_DIR/$VCPKG_DYNAMIC_TRIPLET" ]; then
        VCPKG_DYNAMIC_TRIPLET="${VCPKG_DYNAMIC_TRIPLET}-dynamic"
    fi
elif [[ "$VCPKG_TARGET_TRIPLET" == *-dynamic ]]; then
    VCPKG_DYNAMIC_TRIPLET="$VCPKG_TARGET_TRIPLET"
    VCPKG_STATIC_TRIPLET="${VCPKG_TARGET_TRIPLET%-dynamic}-static"
else
    VCPKG_DYNAMIC_TRIPLET="$VCPKG_TARGET_TRIPLET"
    VCPKG_STATIC_TRIPLET="${VCPKG_TARGET_TRIPLET}-static"
fi

VCPKG_DYNAMIC_PREFIX="$VCPKG_INSTALLED_DIR/$VCPKG_DYNAMIC_TRIPLET"
VCPKG_STATIC_PREFIX="$VCPKG_INSTALLED_DIR/$VCPKG_STATIC_TRIPLET"
VCPKG_PREFIX="$VCPKG_DYNAMIC_PREFIX"
if [ ! -d "$VCPKG_PREFIX" ] && [ -d "$VCPKG_STATIC_PREFIX" ]; then
    VCPKG_PREFIX="$VCPKG_STATIC_PREFIX"
fi

if [ ! -d "$VCPKG_DYNAMIC_PREFIX" ] && [ ! -d "$VCPKG_STATIC_PREFIX" ]; then
    echo "Missing vcpkg install roots for both dynamic/static triplets." >&2
    echo "Expected one of: $VCPKG_DYNAMIC_PREFIX or $VCPKG_STATIC_PREFIX" >&2
    exit 1
fi

PKG_CONFIG_DIRS=()
for prefix in "$VCPKG_DYNAMIC_PREFIX" "$VCPKG_STATIC_PREFIX"; do
    if [ -d "$prefix/lib/pkgconfig" ]; then
        PKG_CONFIG_DIRS+=("$prefix/lib/pkgconfig")
    fi
    if [ -d "$prefix/share/pkgconfig" ]; then
        PKG_CONFIG_DIRS+=("$prefix/share/pkgconfig")
    fi
done

if [ "${#PKG_CONFIG_DIRS[@]}" -gt 0 ]; then
    PKG_CONFIG_PATH_JOINED="$(IFS=:; echo "${PKG_CONFIG_DIRS[*]}")"
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH_JOINED${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH_JOINED"
fi

CMAKE_PREFIXES=()
for prefix in "$VCPKG_DYNAMIC_PREFIX" "$VCPKG_STATIC_PREFIX"; do
    if [ -d "$prefix" ]; then
        CMAKE_PREFIXES+=("$prefix")
    fi
done

mkdir -p "$XDG_CACHE_HOME"

MESON_CPU_FAMILY="x86_64"
CROSS_FILE="$XDG_CACHE_HOME/meson-cross-mingw64.ini"
cat > "$CROSS_FILE" <<EOF
[binaries]
c = 'x86_64-w64-mingw32-gcc'
cpp = 'x86_64-w64-mingw32-g++'
ar = 'x86_64-w64-mingw32-gcc-ar'
ranlib = 'x86_64-w64-mingw32-gcc-ranlib'
strip = 'x86_64-w64-mingw32-strip'
windres = 'x86_64-w64-mingw32-windres'
pkg-config = 'pkg-config'

[host_machine]
system = 'windows'
cpu_family = '${MESON_CPU_FAMILY}'
cpu = 'x86_64'
endian = 'little'

[properties]
needs_exe_wrapper = true

[built-in options]
c_args = ['-D_WIN32_WINNT=${MPV_WIN32_WINNT}', '-DWINVER=${MPV_WIN32_WINNT}']
cpp_args = ['-D_WIN32_WINNT=${MPV_WIN32_WINNT}', '-DWINVER=${MPV_WIN32_WINNT}']
EOF

cd "$MPV_DIR"

echo "Building for target=x86_64-w64-mingw32 from host=$(uname -m)"
echo "Using vcpkg triplet=$VCPKG_TARGET_TRIPLET"
echo "Using vcpkg dynamic triplet=$VCPKG_DYNAMIC_TRIPLET (exists: $([ -d "$VCPKG_DYNAMIC_PREFIX" ] && echo yes || echo no))"
echo "Using vcpkg static triplet=$VCPKG_STATIC_TRIPLET (exists: $([ -d "$VCPKG_STATIC_PREFIX" ] && echo yes || echo no))"
echo "Using PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-}"
echo "Using MPV_WIN32_WINNT=$MPV_WIN32_WINNT"

MESON_ARGS=(
    --buildtype=release
    --cross-file "$CROSS_FILE"
    -Dlibmpv=true
    -Dcplayer=false
    -Dvulkan=enabled
    -Dlua=enabled
)

if [ "${#CMAKE_PREFIXES[@]}" -gt 0 ]; then
    MESON_ARGS+=("-Dcmake_prefix_path=$(IFS=';'; echo "${CMAKE_PREFIXES[*]}")")
fi

if [ ! -d "$BUILD_DIR" ]; then
    echo "Configuring Meson..."
    meson setup "$BUILD_DIR_NAME" "${MESON_ARGS[@]}"
else
    echo "Reconfiguring Meson (wipe old options)..."
    meson setup "$BUILD_DIR_NAME" --wipe "${MESON_ARGS[@]}"
fi

echo "Building..."
meson compile -C "$BUILD_DIR_NAME"

DLL_COUNT="$(find "$BUILD_DIR" -maxdepth 1 -type f -name 'libmpv*.dll' | wc -l | tr -d ' ')"
if [ "$DLL_COUNT" = "0" ]; then
    echo "Build finished but no libmpv*.dll found in $BUILD_DIR" >&2
    exit 1
fi

echo "Build output ready in: $BUILD_DIR"
