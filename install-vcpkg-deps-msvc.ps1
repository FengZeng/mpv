$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { Join-Path $ProjectRoot 'vcpkg' }
$VcpkgInstalledDir = if ($env:VCPKG_INSTALLED_DIR) { $env:VCPKG_INSTALLED_DIR } else { Join-Path $ProjectRoot 'vcpkg_installed' }
$VcpkgTargetTriplet = if ($env:VCPKG_TARGET_TRIPLET) { $env:VCPKG_TARGET_TRIPLET } else { 'x64-windows-mp' }
$OverlayTripletsDir = Join-Path $ProjectRoot 'vcpkg-triplets'
$OverlayPortsDir = Join-Path $ProjectRoot 'vcpkg-ports'

function Resolve-TripletFile {
    param([string]$Triplet)

    $candidates = @(
        (Join-Path $OverlayTripletsDir ("$Triplet.cmake")),
        (Join-Path $VcpkgRoot ("triplets/$Triplet.cmake")),
        (Join-Path $VcpkgRoot ("triplets/community/$Triplet.cmake"))
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Resolve-VcpkgBin {
    $candidates = @(
        (Join-Path $VcpkgRoot 'vcpkg.exe'),
        (Join-Path $VcpkgRoot 'vcpkg')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $bootstrapBat = Join-Path $VcpkgRoot 'bootstrap-vcpkg.bat'
    if (Test-Path $bootstrapBat) {
        Write-Host "vcpkg binary not found, bootstrapping via: $bootstrapBat"
        $bootstrapOutput = & $bootstrapBat -disableMetrics
        $bootstrapExitCode = $LASTEXITCODE
        if ($bootstrapOutput) {
            $bootstrapOutput | ForEach-Object { Write-Host $_ }
        }
        if ($bootstrapExitCode -ne 0) { exit $bootstrapExitCode }
    }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Missing vcpkg executable at $VcpkgRoot/vcpkg(.exe). bootstrap-vcpkg also failed."
}

$VcpkgBin = Resolve-VcpkgBin

$StaticPorts = @(
    'luajit',
    'mujs'
)

$DynamicPorts = @(
    'zlib',
    'bzip2',
    'liblzma',
    'openssl',
    'libarchive',
    'freetype',
    'fribidi',
    'harfbuzz',
    'dav1d',
    'lcms',
    'libass',
    'ffmpeg',
    'uchardet',
    'vulkan',
    'libbluray',
    'libdvdnav',
    'libsmb2',
    'opus',
    'rubberband',
    'libjpeg-turbo',
    'libiconv',
    'shaderc',
    'libplacebo'
)

$FfmpegFeatures = @(
    'ass',
    'bzip2',
    'dav1d',
    'drawtext',
    'freetype',
    'fribidi',
    'iconv',
    'lzma',
    'opus',
    'openssl',
    'rubberband',
    'vulkan',
    'zlib'
)

if ($VcpkgTargetTriplet.EndsWith('-static')) {
    $StaticTriplet = $VcpkgTargetTriplet
    $DynamicTriplet = $VcpkgTargetTriplet.Substring(0, $VcpkgTargetTriplet.Length - 7)
    if (-not (Resolve-TripletFile -Triplet $DynamicTriplet)) {
        $DynamicTriplet = "$DynamicTriplet-dynamic"
    }
} elseif ($VcpkgTargetTriplet.EndsWith('-dynamic')) {
    $DynamicTriplet = $VcpkgTargetTriplet
    $StaticTriplet = "{0}-static" -f $VcpkgTargetTriplet.Substring(0, $VcpkgTargetTriplet.Length - 8)
} else {
    $DynamicTriplet = $VcpkgTargetTriplet
    $StaticTriplet = "$VcpkgTargetTriplet-static"
}

$VcpkgHostTriplet = if ($env:VCPKG_HOST_TRIPLET) {
    $env:VCPKG_HOST_TRIPLET
} elseif ($DynamicTriplet.EndsWith('-dynamic')) {
    $DynamicTriplet
} elseif (Resolve-TripletFile -Triplet "$DynamicTriplet-dynamic") {
    "$DynamicTriplet-dynamic"
} else {
    $DynamicTriplet
}

if ($StaticPorts.Count -gt 0 -and -not (Resolve-TripletFile -Triplet $StaticTriplet)) {
    throw "Missing static triplet file for $StaticTriplet"
}

$StaticSpecs = @()
foreach ($port in $StaticPorts) {
    $StaticSpecs += "$port`:$StaticTriplet"
}

$DynamicSpecs = @()
$ffmpegFeaturesCsv = [string]::Join(',', $FfmpegFeatures)
foreach ($port in $DynamicPorts) {
    if ($port -eq 'ffmpeg' -and $FfmpegFeatures.Count -gt 0) {
        $DynamicSpecs += "ffmpeg[$ffmpegFeaturesCsv]`:$DynamicTriplet"
    } else {
        $DynamicSpecs += "$port`:$DynamicTriplet"
    }
}

if ($StaticSpecs.Count -gt 0) {
    Write-Host "Step 1/2: installing static ports with triplet: $StaticTriplet"
    & $VcpkgBin install `
        --recurse `
        "--host-triplet=$VcpkgHostTriplet" `
        "--overlay-ports=$OverlayPortsDir" `
        "--overlay-triplets=$OverlayTripletsDir" `
        "--x-install-root=$VcpkgInstalledDir" `
        @StaticSpecs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($DynamicSpecs.Count -gt 0) {
    Write-Host "Step 2/2: installing dynamic ports with triplet: $DynamicTriplet"
    if ($FfmpegFeatures.Count -gt 0) {
        Write-Host "ffmpeg features: $($FfmpegFeatures -join ', ')"
    }
    & $VcpkgBin install `
        --recurse `
        "--host-triplet=$VcpkgHostTriplet" `
        "--overlay-ports=$OverlayPortsDir" `
        "--overlay-triplets=$OverlayTripletsDir" `
        "--x-install-root=$VcpkgInstalledDir" `
        @DynamicSpecs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($StaticSpecs.Count -eq 0 -and $DynamicSpecs.Count -eq 0) {
    throw 'No ports to install.'
}
