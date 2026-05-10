# Soia Mpv Library

This project builds the `mpv` library (`libmpv`) used by the Soia Media Player.

It is designed for GitHub Actions CI, and can also be run locally for testing.

## Output Artifacts

Each successful build generates a self-contained runtime package containing:

- `libmpv` runtime library (`.dylib` on macOS, `.dll` on mingw64, `.so` on Linux)
- `soia_utils` runtime library for the current target platform
- `libmpv` link libraries on mingw64 (`.lib`/`.a`/`.dll.a`, when generated)
- all non-system runtime dynamic dependencies (recursive)
- Linux package includes runtime dependencies recursively (excluding core glibc/loader libraries)
- rewritten install names (`@rpath`) and runtime search path (`@loader_path`) on macOS
- SHA256 checksum file

This package is intended to run without requiring Homebrew on the target machine.

## Local Build (MacOS)

Download source and build:

```bash
bash ./install-vcpkg-deps.sh
bash ./download.sh
bash ./build-macos.sh
```

Build a specific mpv version:

```bash
MPV_VERSION=0.41.0 bash ./download.sh
bash ./build-macos.sh
```

`install-vcpkg-deps.sh` bootstraps vcpkg and pins it to tag `2026.04.27` by default. Override with `VCPKG_REF=...` only when intentionally updating the dependency baseline.

Build an x64 macOS library on an arm64 macOS host:

```bash
VCPKG_TARGET_TRIPLET=x64-osx-mp bash ./install-vcpkg-deps.sh
bash ./download.sh
MPV_TARGET_ARCH=x86_64 VCPKG_TARGET_TRIPLET=x64-osx-mp bash ./build-macos.sh
MPV_TARGET_ARCH=x86_64 VCPKG_TARGET_TRIPLET=x64-osx-mp \
  bash ./package-macos-runtime.sh --pkg-name libmpv-local-macos-x86_64
```

The x64 dependency install uses `vcpkg_installed/x64-osx-mp`, separate from the default arm64 triplet.

Build a local runtime package:

```bash
bash ./package-macos-runtime.sh --pkg-name libmpv-local-macos
```

## Local Build (mingw64 / MSYS2)

Download source and build in `MSYS2 MINGW64` shell:

```bash
bash ./download.sh
bash ./build-mingw64.sh
```

Build a local runtime package:

```bash
bash ./package-mingw64-runtime.sh --pkg-name libmpv-local-windows-mingw64-x86_64
```

## Local Build (Linux)

Install dependencies on Ubuntu/Debian (example):

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential git curl python3 meson ninja-build pkg-config \
  libfreetype-dev libfribidi-dev liblcms2-dev libluajit-5.1-dev \
  libass-dev libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev \
  libswresample-dev libswscale-dev \
  libpipewire-0.3-dev libpulse-dev \
  libxss-dev libxpresent-dev \
  libwayland-dev wayland-protocols libxkbcommon-dev \
  libarchive-dev libbluray-dev libcdio-paranoia-dev libdvdnav-dev \
  librubberband-dev libzimg-dev libplacebo-dev libvulkan-dev patchelf
```

Download source and build:

```bash
bash ./download.sh
bash ./build-linux.sh
```

Build a local runtime package:

```bash
bash ./package-linux-runtime.sh --pkg-name libmpv-local-linux
```
