[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [string]$Remote = 'origin',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = (& git @Arguments 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed.`n$output"
    }
    return $output
}

function Test-GitTagExists {
    param(
        [Parameter(Mandatory = $true)][string]$RemoteName,
        [Parameter(Mandatory = $true)][string]$Tag
    )

    $local = & git rev-parse --verify --quiet "refs/tags/$Tag" 2>$null
    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    $remote = & git ls-remote --tags $RemoteName "refs/tags/$Tag" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not query tags on remote '$RemoteName'."
    }
    return -not [string]::IsNullOrWhiteSpace(($remote | Out-String))
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $currentBranch = Invoke-GitText @('branch', '--show-current')
    if ($currentBranch -ne $Branch) {
        throw "Release must run from '$Branch', currently on '$currentBranch'."
    }

    $status = Invoke-GitText @('status', '--porcelain', '--untracked-files=all')
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        throw "The working tree must be clean before releasing.`n$status"
    }

    Invoke-GitText @('fetch', '--quiet', $Remote, $Branch) | Out-Null
    $localCommit = Invoke-GitText @('rev-parse', 'HEAD')
    $remoteCommit = Invoke-GitText @('rev-parse', "$Remote/$Branch")
    if ($localCommit -ne $remoteCommit) {
        throw "Local '$Branch' is not synchronized with '$Remote/$Branch'. Pull or push it first."
    }

    $pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
    $pubspec = [IO.File]::ReadAllText($pubspecPath)
    $versionMatch = [regex]::Match(
        $pubspec,
        '(?m)^version:\s*(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\+(?<build>\d+)\s*$'
    )
    if (-not $versionMatch.Success) {
        throw 'Could not find a version in pubspec.yaml. Expected MAJOR.MINOR.PATCH+BUILD.'
    }

    $currentVersion = '{0}.{1}.{2}' -f `
        $versionMatch.Groups['major'].Value,
        $versionMatch.Groups['minor'].Value,
        $versionMatch.Groups['patch'].Value
    $currentBuild = [int]$versionMatch.Groups['build'].Value
    $nextVersion = if ([string]::IsNullOrWhiteSpace($Version)) {
        '{0}.{1}.{2}' -f `
            $versionMatch.Groups['major'].Value,
            $versionMatch.Groups['minor'].Value,
            ([int]$versionMatch.Groups['patch'].Value + 1)
    } else {
        $Version
    }
    if ($nextVersion -eq $currentVersion) {
        throw "Version $nextVersion is already in pubspec.yaml. Choose a newer version."
    }

    $tag = "v$nextVersion"
    if (Test-GitTagExists -RemoteName $Remote -Tag $tag) {
        throw "Tag $tag already exists locally or on $Remote."
    }

    $nextBuild = $currentBuild + 1
    $newVersionLine = "version: $nextVersion+$nextBuild"
    $versionLinePattern = '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$'
    $updatedPubspec = [regex]::Replace($pubspec, $versionLinePattern, $newVersionLine, 1)
    if ($updatedPubspec -eq $pubspec) {
        throw 'The version line in pubspec.yaml was not updated.'
    }

    Write-Host "Preparing $tag from $currentVersion+$currentBuild to $nextVersion+$nextBuild."
    if (-not $PSCmdlet.ShouldProcess("$Remote/$Branch and tag $tag", 'Create and push release')) {
        return
    }

    [IO.File]::WriteAllText($pubspecPath, $updatedPubspec, [Text.UTF8Encoding]::new($false))
    Invoke-GitText @('add', '--', 'pubspec.yaml') | Out-Null
    Invoke-GitText @('commit', '-m', "Release $tag") | Out-Null
    Invoke-GitText @('tag', '--annotate', $tag, '--message', "Release $tag") | Out-Null
    Invoke-GitText @('push', $Remote, "$Branch") | Out-Null
    Invoke-GitText @('push', $Remote, $tag) | Out-Null

    Write-Host "Pushed $tag. GitHub Actions will build Web and Android assets and publish the Release."
} finally {
    Pop-Location
}
