# Creates a GitHub release for every version tag from docs/CHANGELOG_RU.md (needs the GitHub CLI: winget install GitHub.cli; gh auth login).
# Run from the repository root:  powershell -ExecutionPolicy Bypass -File tools\make_releases.ps1
# Preview builds are published as pre-releases. Existing releases are skipped.
# The release gets the game as a zip with the exe (from %LOCALAPPDATA%\Programs\ForestRail\<version>\), so install the build before running this.
$ErrorActionPreference = "Stop"
$log = Get-Content -Raw -Encoding UTF8 "docs\CHANGELOG_RU.md"
$lines = $log -split "`r?`n"
$existing = (& gh release list --limit 200 --json tagName | ConvertFrom-Json).tagName
$tags = & git tag --list "v1.*" --sort=creatordate
foreach ($tag in $tags) {
    if ($existing -contains $tag) { Write-Host "skip $tag (already a release)"; continue }
    $version = $tag -replace '^v', ''
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^#{2,3} $([regex]::Escape($version))( |$)") { $start = $i; break }
    }
    if ($start -lt 0) { Write-Host "no changelog entry for $tag, skipped"; continue }
    $body = @()
    for ($j = $start + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^#{2,3} ' -or $lines[$j] -match '^---') { break }
        $body += $lines[$j]
    }
    $notes = ($body -join "`n").Trim()
    $args = @("release", "create", $tag, "--title", $version, "--notes", $notes)
    if ($version -match 'preview') { $args += "--prerelease" }
    & gh @args
    Write-Host "created $tag"
    # the game itself: a zip with the Windows exe, made from the installed build (outputs\release is not in git)
    $zip = "outputs\release\ForestRail-$version-windows.zip"
    if (-not (Test-Path $zip)) {
        $exe = Join-Path $env:LOCALAPPDATA "Programs\ForestRail\$version\ForestRail.exe"
        if (Test-Path $exe) { New-Item -ItemType Directory -Force "outputs\release" | Out-Null; Compress-Archive -Path $exe -DestinationPath $zip }
    }
    if (Test-Path $zip) { & gh release upload $tag $zip; Write-Host "attached $zip" } else { Write-Host "no build found for $version, release has no exe" }
}
