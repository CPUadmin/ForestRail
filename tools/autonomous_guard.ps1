param([string]$Root=(Split-Path $PSScriptRoot -Parent),[switch]$ProbeOnly,[switch]$SelfTest)
$ErrorActionPreference='Stop'
$Root=(Resolve-Path -LiteralPath $Root).Path
$runtime=Join-Path $Root 'qa/autonomous_run'
$deadline=[DateTimeOffset]::Parse('2026-10-29T10:00:00+03:00')
function Stop-Reason([int]$Battery,[double]$Remaining,[DateTimeOffset]$Now) {
    if ($Battery -le 10) { return 'battery_10_percent' }
    if ($Remaining -lt 10) { return 'remaining_limit_below_10_percent' }
    if ($Now -ge $deadline) { return '10_00_moscow' }
    return ''
}
if ($SelfTest) {
    $early=$deadline.AddHours(-1)
    $tests=@(
        ((Stop-Reason 10 30 $early) -eq 'battery_10_percent'),
        ((Stop-Reason 85 9.9 $early) -eq 'remaining_limit_below_10_percent'),
        ((Stop-Reason 85 30 $deadline) -eq '10_00_moscow'),
        ((Stop-Reason 11 10 $early) -eq '')
    )
    if ($tests -contains $false) { throw 'Stop-condition self test failed' }
    @{checks=$tests.Count;passed=$true} | ConvertTo-Json
    exit 0
}
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ForestRailRunGuard {
 [StructLayout(LayoutKind.Sequential)] public struct Power {
  public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
  public uint BatteryLifeTime, BatteryFullLifeTime;
 }
 [DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out Power p);
 [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
}
'@
function Write-State([string]$Name,$Value) {
    $target=Join-Path $runtime $Name
    $temporary=$target+'.tmp-'+$PID
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding utf8
    Move-Item -LiteralPath $temporary -Destination $target -Force
}
function Read-State {
    $power=New-Object ForestRailRunGuard+Power
    if (-not [ForestRailRunGuard]::GetSystemPowerStatus([ref]$power)) { throw 'Cannot read power status' }
    $battery=[int]$power.BatteryLifePercent
    if ($battery -eq 255) {
        $battery=[int](Get-CimInstance Win32_Battery | Select-Object -First 1 -ExpandProperty EstimatedChargeRemaining)
    }
    $limits=$null
    for ($retry=0;$retry -lt 3;$retry++) {
        try { $limits=Get-Content -LiteralPath (Join-Path $runtime 'limits.json') -Raw | ConvertFrom-Json;break }
        catch { if ($retry -eq 2) { throw };Start-Sleep -Milliseconds 100 }
    }
    $now=[DateTimeOffset]::UtcNow
    $reason=Stop-Reason $battery ([double]$limits.remaining_percent) $now
    if (-not $reason -and ($now-[DateTimeOffset]$limits.checked_at_utc).TotalMinutes -gt 15) { $reason='limit_check_stale' }
    return @{pid=$PID;checked_at_utc=$now.ToString('o');moscow_time=$now.ToOffset([TimeSpan]::FromHours(3)).ToString('o');battery_percent=$battery;ac_connected=($power.ACLineStatus -eq 1);remaining_percent=[double]$limits.remaining_percent;deadline=$deadline.ToString('o');stop_reason=$reason;awake_request=$false}
}
$state=Read-State
if ($ProbeOnly) { $state | ConvertTo-Json;exit 0 }
$previous=Join-Path $runtime 'guard_state.json'
if (Test-Path -LiteralPath $previous) {
    $old=Get-Content -LiteralPath $previous -Raw | ConvertFrom-Json
    if ($old.pid -ne $PID -and (Get-Process -Id $old.pid -ErrorAction SilentlyContinue)) { throw 'Guard already running' }
}
$lastCheckpoint=[DateTimeOffset]::UtcNow
try {
    if ([ForestRailRunGuard]::SetThreadExecutionState([uint32]2147483649) -eq 0) { throw 'Cannot hold system awake' }
    while ($true) {
        $state=Read-State
        $marker=Join-Path $runtime 'stop.json'
        if ((Test-Path -LiteralPath $marker) -and -not $state.stop_reason) { $state.stop_reason='existing_stop_marker' }
        $state.awake_request=$true
        Write-State 'guard_state.json' $state
        if ($state.stop_reason) {
            Write-State 'stop.json' $state
            # Stop only automatic QA started inside this project, never a
            # player's game, Codex, or an unrelated process.
            Get-CimInstance Win32_Process | Where-Object {
                $_.CommandLine -and $_.CommandLine.Contains($Root) -and $_.CommandLine.Contains('--qa-suite=') -and ($_.Name -like 'Godot*' -or $_.Name -like 'ForestRail_P*')
            } | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
            & (Join-Path $PSScriptRoot 'autonomous_checkpoint.ps1') -Root $Root -Reason $state.stop_reason
            break
        }
        if (([DateTimeOffset]::UtcNow-$lastCheckpoint).TotalMinutes -ge 10) {
            & (Join-Path $PSScriptRoot 'autonomous_checkpoint.ps1') -Root $Root -Reason 'periodic'
            $lastCheckpoint=[DateTimeOffset]::UtcNow
        }
        Start-Sleep -Seconds 10
    }
} catch {
    Write-State 'guard_error.json' @{at_utc=[DateTimeOffset]::UtcNow.ToString('o');message=$_.Exception.Message}
    if (-not $state) { $state=@{} }
    $state.stop_reason='guard_error'
    Write-State 'stop.json' $state
    & (Join-Path $PSScriptRoot 'autonomous_checkpoint.ps1') -Root $Root -Reason 'guard-error'
    throw
} finally {
    [void][ForestRailRunGuard]::SetThreadExecutionState([uint32]2147483648)
    if ($state) { $state.awake_request=$false;$state.released_at_utc=[DateTimeOffset]::UtcNow.ToString('o');Write-State 'guard_state.json' $state }
}
