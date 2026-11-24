$ErrorActionPreference = 'Stop'

if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'Run this script on Windows x64. Flutter builds for the host architecture.'
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $bundle = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    $archive = Join-Path $projectRoot 'build\jotcalc-windows-x64.zip'
    $requiredFiles = @(
        'JotCalc.exe'
        'flutter_windows.dll'
        'data\app.so'
        'data\icudtl.dat'
        'msvcp140.dll'
        'vcruntime140.dll'
        'vcruntime140_1.dll'
    )
    foreach ($name in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $bundle $name) -PathType Leaf)) {
            throw "The Windows release is missing $name in $bundle."
        }
    }

    $items = Get-ChildItem -LiteralPath $bundle |
        Where-Object { $_.PSIsContainer -or $_.Extension -notin @('.pdb', '.lib', '.exp') }
    $temporaryArchive = "$archive.$([Guid]::NewGuid().ToString('N')).zip"
    try {
        Compress-Archive -LiteralPath $items.FullName -DestinationPath $temporaryArchive -CompressionLevel Optimal
        $checksum = (Get-FileHash -LiteralPath $temporaryArchive -Algorithm SHA256).Hash.ToLowerInvariant()
        Move-Item -LiteralPath $temporaryArchive -Destination $archive -Force
        "$checksum  $(Split-Path -Leaf $archive)" | Set-Content -LiteralPath "$archive.sha256" -Encoding ascii
    } finally {
        if (Test-Path -LiteralPath $temporaryArchive) {
            Remove-Item -LiteralPath $temporaryArchive
        }
    }

    Write-Host "Windows release created at $archive"
} finally {
    Pop-Location
}
