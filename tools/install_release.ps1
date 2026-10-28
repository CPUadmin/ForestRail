param([string]$Version = '1.1.0', [string]$SourceExecutable = '', [string]$ProfileDirectory = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sourceExe = Join-Path $projectRoot 'release/ForestRail/ForestRail.exe'
if ($SourceExecutable -ne '') { $sourceExe = (Resolve-Path -LiteralPath $SourceExecutable).Path }
$installDir = Join-Path $env:LOCALAPPDATA "Programs/ForestRail/$Version"
$installedExe = Join-Path $installDir 'ForestRail.exe'
$saveDir = Join-Path $env:APPDATA 'ForestRail'
function Get-CareerHashes {
    $result = @{}
    foreach ($name in @('save_v2.json','save_v2.backup.json','settings.json')) {
        $path = Join-Path $saveDir $name
        if (Test-Path -LiteralPath $path) { $result[$name] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    }
    return $result
}
$before = Get-CareerHashes
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item -LiteralPath $sourceExe -Destination $installedExe
$expected = (Get-FileHash -LiteralPath $sourceExe -Algorithm SHA256).Hash
if ((Get-FileHash -LiteralPath $installedExe -Algorithm SHA256).Hash -ne $expected) { throw 'Installed file differs from release' }
$shell = New-Object -ComObject WScript.Shell
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Лесная колея.lnk'
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $installedExe
$shortcut.Arguments = ''
if ($ProfileDirectory -ne '') {
    New-Item -ItemType Directory -Path $ProfileDirectory -Force | Out-Null
    $shortcut.Arguments = '-- --profile-dir="' + $ProfileDirectory + '"'
}
$shortcut.WorkingDirectory = $installDir
$shortcut.Description = "Лесная колея $Version"
$iconSource = Join-Path $projectRoot 'ForestRail/assets/branding/forest_rail_launcher_v1.ico'
if (Test-Path -LiteralPath $iconSource) {
    $brandingDir = Join-Path $env:LOCALAPPDATA 'Programs/ForestRail/Branding'
    New-Item -ItemType Directory -Path $brandingDir -Force | Out-Null
    $iconPath = Join-Path $brandingDir 'ForestRail-v1.ico'
    Copy-Item -LiteralPath $iconSource -Destination $iconPath
    $shortcut.IconLocation = $iconPath + ',0'
}
$shortcut.Save()
$smokeDir = Join-Path $projectRoot 'qa/install_smoke'
New-Item -ItemType Directory -Path $smokeDir -Force | Out-Null
$versionTag = $Version.Replace('.','')
$shot = Join-Path $projectRoot "qa/installed_menu_$versionTag.png"
$launchArgs = @('--',('--qa-dir="{0}"' -f $smokeDir),('--screenshot="{0}"' -f $shot))
$process = Start-Process -FilePath $installedExe -ArgumentList $launchArgs -WorkingDirectory $installDir -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $shot)) { throw 'Installed game did not finish launch check' }
$after = Get-CareerHashes
if (($before | ConvertTo-Json -Compress) -ne ($after | ConvertTo-Json -Compress)) { throw 'Career/settings changed during launch check' }
$report = @{version=$Version; executable=$installedExe; sha256=$expected; shortcut=$shortcutPath; saves_unchanged=$true; save_hashes=$after}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $projectRoot "qa/installation_$versionTag.json") -Encoding utf8
$report | ConvertTo-Json -Depth 5
