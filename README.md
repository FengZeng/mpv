# Soia Mpv Library

This project builds the `mpv` library (`libmpv`) used by the Soia Media Player.

It is designed for GitHub Actions CI, and can also be run locally for testing.

## Output Artifacts

Each successful build generates a self-contained runtime package containing:

- `libmpv` runtime library (`.dylib` on macOS, `.dll` on Windows, `.so` on Linux)
- `soia_utils` runtime library for the current target platform
- `libmpv` link libraries on Windows (`.lib`, when generated)
- all non-system runtime dynamic dependencies (recursive)
- Linux package includes runtime dependencies recursively (excluding core glibc/loader libraries)
- rewritten install names (`@rpath`) and runtime search path (`@loader_path`) on macOS
- SHA256 checksum file

This package is intended to run without requiring Homebrew on the target machine.

## Local Build (MacOS)

Download source and build:

```bash
bash ./download.sh
bash ./build-macos.sh
```

Build a specific mpv version:

```bash
MPV_VERSION=0.41.0 bash ./download.sh
bash ./build-macos.sh
```

Build a local runtime package:

```bash
bash ./package-macos-runtime.sh --pkg-name libmpv-local-macos
```

## Local Build (MSVC / PowerShell)

Install Visual Studio Build Tools (Desktop development with C++) and make sure
`meson` + `ninja` are available in `PATH`.

Then bootstrap vcpkg, install dependencies, and build:

```powershell
bash ./download.sh
powershell -ExecutionPolicy Bypass -File .\install-vcpkg-deps-msvc.ps1
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1
```

## GitHub CI (windows-2022, MSVC)

Recommended CI steps (PowerShell):

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive

- name: Setup Python
  uses: actions/setup-python@v5
  with:
    python-version: "3.11"

- name: Install meson + ninja
  shell: pwsh
  run: |
    python -m pip install --upgrade pip
    python -m pip install meson ninja

- name: Download mpv source
  shell: bash
  run: |
    bash ./download.sh

- name: Install vcpkg deps (MSVC triplet)
  shell: pwsh
  run: |
    ./install-vcpkg-deps-msvc.ps1

- name: Build libmpv (MSVC)
  shell: pwsh
  run: |
    ./build-msvc.ps1
```

Or from bash/MSYS shell:

```bash
bash ./download.sh
bash ./install-vcpkg-deps.sh
bash ./build-msvc.sh
```

Optional: tune minimum Windows target API level (default is `0x0601`, Windows 7):

```powershell
$env:MPV_WIN32_WINNT='0x0603'
powershell -ExecutionPolicy Bypass -File .\install-vcpkg-deps-msvc.ps1
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1
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
