# Creates a GitHub release for every version tag from docs/CHANGELOG_RU.md (needs the GitHub CLI: winget install GitHub.cli; gh auth login).
# Run from the repository root:  powershell -ExecutionPolicy Bypass -File tools\make_releases.ps1
# Preview builds are published as pre-releases. Existing releases are skipped.
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
}
