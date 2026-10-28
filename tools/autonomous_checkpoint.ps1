param([string]$Root=(Split-Path $PSScriptRoot -Parent), [string]$Reason='periodic')
$ErrorActionPreference='Stop'
$Root=(Resolve-Path -LiteralPath $Root).Path
$runtime=Join-Path $Root 'qa/autonomous_run'
$manifest=Join-Path $runtime 'owned_paths.json'
if (-not (Test-Path -LiteralPath $manifest)) { throw 'Owned-file manifest missing' }
$owned=@(Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json)
$paths=@()
foreach ($relative in $owned) {
    $absolute=[IO.Path]::GetFullPath((Join-Path $Root $relative))
    if (-not $absolute.StartsWith($Root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Checkpoint path escaped project' }
    if (Test-Path -LiteralPath $absolute) { $paths+=[string]$relative }
}
if ($paths.Count -eq 0) { throw 'No owned files to checkpoint' }
Push-Location $Root
try {
    $saved=$false
    for ($attempt=0;$attempt -lt 4;$attempt++) {
        & git add -- @paths 2>&1 | Out-File -LiteralPath (Join-Path $runtime 'checkpoint.log') -Append -Encoding utf8
        if ($LASTEXITCODE -eq 0) {
            & git diff --quiet HEAD -- @paths
            if ($LASTEXITCODE -eq 0) { $saved=$true;break }
            & git commit --only -m "Autonomous checkpoint: $Reason" -- @paths 2>&1 | Out-File -LiteralPath (Join-Path $runtime 'checkpoint.log') -Append -Encoding utf8
            if ($LASTEXITCODE -eq 0) { $saved=$true;break }
        }
        Start-Sleep -Seconds 2
    }
    if (-not $saved) { throw 'Checkpoint commit failed; working files remain on disk' }
    & git bundle create (Join-Path $runtime 'ForestRail_Autonomous.bundle') --all 2>&1 | Out-File -LiteralPath (Join-Path $runtime 'checkpoint.log') -Append -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Bundle failed; Git commit remains saved' }
    $commit=(& git rev-parse HEAD).Trim()
    @{saved_at_utc=[DateTimeOffset]::UtcNow.ToString('o');reason=$Reason;commit=$commit;bundle='ForestRail_Autonomous.bundle';owned_files=$paths.Count} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtime 'checkpoint.json') -Encoding utf8
} finally { Pop-Location }
