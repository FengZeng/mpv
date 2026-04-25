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

## Local Build (Windows, MSVC / PowerShell)

### 1) Prerequisites

Please install these tools first:

- Visual Studio 2022 Build Tools (or Visual Studio 2022)
  - workload: `Desktop development with C++`
  - include latest MSVC toolset + Windows 10/11 SDK
- Git for Windows (for `git` and `bash`)
- Python 3.11+ (with `pip`)

Install Meson/Ninja:

```powershell
python -m pip install --upgrade pip
python -m pip install meson ninja
```

Open `x64 Native Tools Command Prompt for VS 2022`, then start PowerShell in the
same window and enter repo root:

```powershell
powershell
cd D:\soia\mpv
```

Quick check:

```powershell
cl
meson --version
ninja --version
```

`cl` should print Microsoft C/C++ compiler banner (it may also print a warning like
`D8003` when no source file is passed; that is fine for this check).

### 2) Build from repo root

In the same PowerShell window above, run from repository root (`D:\soia\mpv`):

```powershell
bash ./download.sh
powershell -ExecutionPolicy Bypass -File .\install-vcpkg-deps-msvc.ps1
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1
```

### 3) Build outputs

Default output directory:

- `vendor/mpv/build-msvc`

Expected artifacts include:

- `libmpv*.dll`
- `libmpv*.lib` (when generated)

### 4) Useful environment overrides (optional)

- `MPV_VERSION`: build a specific mpv version during download
- `VCPKG_TARGET_TRIPLET`: change target triplet (default `x64-windows-mp`)
- `VCPKG_INSTALLED_DIR`: override vcpkg install root
- `MPV_BUILD_DIR`: custom Meson build directory name
- `MPV_WIN32_WINNT`: minimum Windows API level (default `0x0601`)

Example:

```powershell
$env:MPV_VERSION='0.41.0'
$env:MPV_WIN32_WINNT='0x0603'
bash ./download.sh
powershell -ExecutionPolicy Bypass -File .\install-vcpkg-deps-msvc.ps1
powershell -ExecutionPolicy Bypass -File .\build-msvc.ps1
```

### 5) Troubleshooting

- `meson not found in PATH` / `ninja not found in PATH`:
  - run `python -m pip install meson ninja`
  - reopen terminal and retry
- `cl` command not found:
  - open `x64 Native Tools Command Prompt for VS 2022`, then run PowerShell in that
    window (`powershell`)
  - or reinstall VS Build Tools with C++ workload
- vcpkg install fails midway:
  - rerun `.\install-vcpkg-deps-msvc.ps1` (safe to retry)
- Build completes but no `libmpv*.dll`:
  - check Meson configure/build output for first failing target and dependency

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
