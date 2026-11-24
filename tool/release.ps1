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

    $tagRef = "refs/tags/$Tag"
    $localRefs = Invoke-GitText @('for-each-ref', '--format=%(refname)', $tagRef)
    if (($localRefs -split '\r?\n') -contains $tagRef) {
        return $true
    }

    $remoteRefs = Invoke-GitText @('ls-remote', '--tags', $RemoteName, $tagRef)
    return -not [string]::IsNullOrWhiteSpace($remoteRefs)
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
    $commonCommit = Invoke-GitText @('merge-base', $localCommit, $remoteCommit)
    if ($commonCommit -ne $remoteCommit) {
        throw "Local '$Branch' is missing commits from '$Remote/$Branch'. Integrate them before releasing."
    }

    $pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
    $pubspec = [IO.File]::ReadAllText($pubspecPath)
    $versionMatch = [regex]::Match(
        $pubspec,
        '(?m)^version:[ \t]*(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\+(?<build>\d+)(?=[ \t]*\r?$)'
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
    $updatedPubspec = $pubspec.Remove($versionMatch.Index, $versionMatch.Length).Insert($versionMatch.Index, $newVersionLine)

    Write-Host "Preparing $tag from $currentVersion+$currentBuild to $nextVersion+$nextBuild."
    if (-not $PSCmdlet.ShouldProcess("$Remote/$Branch and tag $tag", 'Create and push release')) {
        return
    }

    [IO.File]::WriteAllText($pubspecPath, $updatedPubspec, [Text.UTF8Encoding]::new($false))
    Invoke-GitText @('add', '--', 'pubspec.yaml') | Out-Null
    Invoke-GitText @('commit', '-m', "Release $tag") | Out-Null
    Invoke-GitText @('tag', '--annotate', $tag, '--message', "Release $tag") | Out-Null
    try {
        Invoke-GitText @('push', '--atomic', $Remote, "refs/heads/$Branch", "refs/tags/$tag") | Out-Null
    } catch {
        throw "Release $tag is prepared locally. After resolving the push error, retry with git push --atomic $Remote refs/heads/$Branch refs/tags/$tag.`n$_"
    }

    Write-Host "Pushed $tag. GitHub Actions will build Web, Android, and Windows assets and publish the Release."
} finally {
    Pop-Location
}
