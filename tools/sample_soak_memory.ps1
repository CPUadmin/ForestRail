param([int]$TargetProcessId,[string]$Root=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$identity=Get-CimInstance Win32_Process -Filter "ProcessId=$TargetProcessId"
if (-not $identity.CommandLine.Contains('--qa-suite=check_soak_p8') -or -not $identity.CommandLine.Contains($Root)) { throw 'Not this project soak process' }
$target=Get-Process -Id $TargetProcessId
$output=Join-Path $Root 'qa/v3_p8/process_samples.jsonl'
while (-not $target.HasExited) {
    $target.Refresh()
    if ($target.HasExited) { break }
    @{at_utc=[DateTimeOffset]::UtcNow.ToString('o');pid=$TargetProcessId;working_set_bytes=$target.WorkingSet64;private_bytes=$target.PrivateMemorySize64;cpu_seconds=$target.CPU} | ConvertTo-Json -Compress | Add-Content -LiteralPath $output -Encoding utf8
    Start-Sleep -Seconds 30
}
