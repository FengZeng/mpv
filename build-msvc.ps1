$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VendorDir = Join-Path $ProjectRoot 'vendor'
$MpvDir = Join-Path $VendorDir 'mpv'
$BuildDirName = if ($env:MPV_BUILD_DIR) { $env:MPV_BUILD_DIR } else { 'build-msvc' }
$BuildDir = Join-Path $MpvDir $BuildDirName
$VcpkgInstalledDir = if ($env:VCPKG_INSTALLED_DIR) { $env:VCPKG_INSTALLED_DIR } else { Join-Path $ProjectRoot 'vcpkg_installed' }
$VcpkgTargetTriplet = if ($env:VCPKG_TARGET_TRIPLET) { $env:VCPKG_TARGET_TRIPLET } else { 'x64-windows-mp' }
$MpvWin32Winnt = if ($env:MPV_WIN32_WINNT) { $env:MPV_WIN32_WINNT } else { '0x0601' }

if (-not (Test-Path $MpvDir)) {
    throw "Missing mpv source: $MpvDir. Run: ./download.sh"
}

if ($VcpkgTargetTriplet.EndsWith('-static')) {
    $VcpkgStaticTriplet = $VcpkgTargetTriplet
    $VcpkgDynamicTriplet = $VcpkgTargetTriplet.Substring(0, $VcpkgTargetTriplet.Length - 7)
    $candidateDynamic = Join-Path $VcpkgInstalledDir $VcpkgDynamicTriplet
    if (-not (Test-Path $candidateDynamic)) {
        $VcpkgDynamicTriplet = "$VcpkgDynamicTriplet-dynamic"
    }
} elseif ($VcpkgTargetTriplet.EndsWith('-dynamic')) {
    $VcpkgDynamicTriplet = $VcpkgTargetTriplet
    $VcpkgStaticTriplet = "{0}-static" -f $VcpkgTargetTriplet.Substring(0, $VcpkgTargetTriplet.Length - 8)
} else {
    $VcpkgDynamicTriplet = $VcpkgTargetTriplet
    $VcpkgStaticTriplet = "$VcpkgTargetTriplet-static"
}

$VcpkgDynamicPrefix = Join-Path $VcpkgInstalledDir $VcpkgDynamicTriplet
$VcpkgStaticPrefix = Join-Path $VcpkgInstalledDir $VcpkgStaticTriplet
$VcpkgPrefix = $VcpkgDynamicPrefix
if (-not (Test-Path $VcpkgPrefix) -and (Test-Path $VcpkgStaticPrefix)) {
    $VcpkgPrefix = $VcpkgStaticPrefix
}

if (-not (Test-Path $VcpkgDynamicPrefix) -and -not (Test-Path $VcpkgStaticPrefix)) {
    throw "Missing vcpkg install roots for both dynamic/static triplets. Expected one of: $VcpkgDynamicPrefix or $VcpkgStaticPrefix"
}

if (-not (Get-Command meson -ErrorAction SilentlyContinue)) {
    throw 'meson not found in PATH'
}
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    throw 'ninja not found in PATH'
}

$pkgConfigDirs = @()
if (Test-Path $VcpkgDynamicPrefix) {
    $pkgConfigDirs += (Join-Path $VcpkgDynamicPrefix 'lib/pkgconfig')
    $pkgConfigDirs += (Join-Path $VcpkgDynamicPrefix 'share/pkgconfig')
}
if (Test-Path $VcpkgStaticPrefix) {
    $pkgConfigDirs += (Join-Path $VcpkgStaticPrefix 'lib/pkgconfig')
    $pkgConfigDirs += (Join-Path $VcpkgStaticPrefix 'share/pkgconfig')
}

$pkgConfigDirs = $pkgConfigDirs | Where-Object { Test-Path $_ }
if ($pkgConfigDirs.Count -gt 0) {
    $pkgConfigPath = [string]::Join(';', $pkgConfigDirs)
    if ($env:PKG_CONFIG_PATH) {
        $env:PKG_CONFIG_PATH = "$pkgConfigPath;$($env:PKG_CONFIG_PATH)"
    } else {
        $env:PKG_CONFIG_PATH = $pkgConfigPath
    }
    $env:PKG_CONFIG_LIBDIR = $pkgConfigPath
}

$cmakePrefixes = @()
if (Test-Path $VcpkgDynamicPrefix) { $cmakePrefixes += $VcpkgDynamicPrefix }
if (Test-Path $VcpkgStaticPrefix) { $cmakePrefixes += $VcpkgStaticPrefix }
$cmakePrefixes = $cmakePrefixes | Select-Object -Unique
$cmakePrefixArg = [string]::Join(';', $cmakePrefixes)

$includeDir = Join-Path $VcpkgPrefix 'include'
$libDir = Join-Path $VcpkgPrefix 'lib'
$clFlags = "/D_WIN32_WINNT=$MpvWin32Winnt /DWINVER=$MpvWin32Winnt"
if (Test-Path $includeDir) {
    $clFlags = "$clFlags /I`"$includeDir`""
}
if ($env:CL) {
    $env:CL = "$clFlags $($env:CL)"
} else {
    $env:CL = $clFlags
}
if (Test-Path $libDir) {
    if ($env:LINK) {
        $env:LINK = "/LIBPATH:`"$libDir`" $($env:LINK)"
    } else {
        $env:LINK = "/LIBPATH:`"$libDir`""
    }
}

Write-Host "Building with VCPKG_TARGET_TRIPLET=$VcpkgTargetTriplet"
Write-Host "Using vcpkg dynamic triplet=$VcpkgDynamicTriplet (exists: $(Test-Path $VcpkgDynamicPrefix))"
Write-Host "Using vcpkg static triplet=$VcpkgStaticTriplet (exists: $(Test-Path $VcpkgStaticPrefix))"
Write-Host "Using MPV_WIN32_WINNT=$MpvWin32Winnt"

Set-Location $MpvDir

$mesonArgs = @(
    '--buildtype=release',
    '--vsenv',
    '-Dlibmpv=true',
    '-Dcplayer=false',
    '-Dvulkan=enabled',
    '-Dlua=enabled'
)
if ($cmakePrefixArg) {
    $mesonArgs += "-Dcmake_prefix_path=$cmakePrefixArg"
}

if (-not (Test-Path $BuildDir)) {
    Write-Host 'Configuring Meson...'
    & meson setup $BuildDirName @mesonArgs
} else {
    Write-Host 'Reconfiguring Meson (wipe old options)...'
    & meson setup $BuildDirName --reconfigure @mesonArgs
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Building...'
& meson compile -C $BuildDirName
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dlls = Get-ChildItem -Path $BuildDir -Filter 'libmpv*.dll' -ErrorAction SilentlyContinue
if (-not $dlls) {
    throw "Build finished but no libmpv*.dll found in $BuildDir"
}

Write-Host "Build output ready in: $BuildDir"
