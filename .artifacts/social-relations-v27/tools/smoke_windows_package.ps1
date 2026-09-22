param([Parameter(Mandatory=$true)][string]$ZipPath)
. "$PSScriptRoot/windows_common.ps1"
$root = Split-Path $PSScriptRoot -Parent
$zip = (Resolve-Path -LiteralPath $ZipPath).Path
$expected = ([IO.File]::ReadAllText($zip + '.sha256') -split '\s+')[0]
if ((Get-FileHash $zip).Hash -ne $expected) { throw 'ZIP SHA256 mismatch.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this acceptance check without administrator elevation.' }
$chinese = -join ([char[]]@(0x9b3c,0x5e02,0x5f53,0x94fa))
$outside = Join-Path ([IO.Path]::GetTempPath()) ("$chinese M8A Test " + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $outside | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath "$outside/game"
$exe = "$outside/game/Pawnshop.exe"
$info = Get-Content "$outside/game/BUILD_INFO.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ((Get-FileHash $exe).Hash -ne $info.exe_sha256 -or (Get-FileHash "$outside/game/Pawnshop.pck").Hash -ne $info.pck_sha256) { throw 'Unpacked binaries differ from build metadata.' }
$oldAppData = $env:APPDATA
# Read only hashes of files in the explicit developer save directory; never copy saves.
$devDir = Join-Path $oldAppData ('Godot/app_userdata/' + $chinese + '/p0')
function Snapshot-DeveloperSaves {
    $snapshot = [ordered]@{}
    if (Test-Path -LiteralPath $devDir) {
        foreach ($file in Get-ChildItem -LiteralPath $devDir -File) { $snapshot[$file.Name] = (Get-FileHash -LiteralPath $file.FullName).Hash }
    }
    return ($snapshot | ConvertTo-Json -Compress)
}
$before = Snapshot-DeveloperSaves
$oldLocation = Get-Location
try {
    $env:APPDATA = "$outside/appdata"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Set-Location "$outside/game"
    Invoke-GodotChecked $exe @('--headless','--quit-after','60') "$outside/exe-headless.log" 'Godot Engine v4.6.1' | Out-Null
    $runtimeLog = "$env:APPDATA/GhostMarketPawnshop-M8A/logs/godot.log"
    if (-not (Test-Path $runtimeLog)) { throw 'Exported custom feature did not select isolated user directory.' }
    $captureLog = ''
    foreach ($size in @('1280x720','1600x900')) {
        Invoke-GodotChecked $exe @('--resolution',$size,'--quit-after','60') "$outside/exe-window-$size.log" 'Godot Engine v4.6.1' | Out-Null
        $captureLog += Invoke-GodotChecked $exe @('--resolution',$size,'--write-movie',"$outside/release-$size.png",'--fixed-fps','30','--quit-after','3') "$outside/exe-capture-$size.log" 'Done recording movie'
    }
    if (Test-Path "$env:APPDATA/Godot/app_userdata") { throw 'Release unexpectedly used default developer user directory.' }
    $after = Snapshot-DeveloperSaves
    if ($before -ne $after) { throw 'Developer save hashes changed during package startup check.' }
    $report = [ordered]@{
        zip=$zip; zip_sha256=$expected; extracted_outside_source=$outside;
        ordinary_user=$true; admin=$false; source_or_editor_arguments_used=$false;
        authenticode_status=[string](Get-AuthenticodeSignature -LiteralPath $exe).Status;
        headless_startup='passed'; graphical_startup='passed';
        requested_window_sizes=@('1280x720','1600x900');
        capture_resolution_note='MovieWriter records the project base viewport (1280x720), not proof of a native 1600x900 layout. Native DPI/resize acceptance is pending.';
        custom_user_directory='verified by engine-created default log in isolated APPDATA/GhostMarketPawnshop-M8A/logs';
        developer_save_hashes_unchanged=$true; developer_save_snapshot=($before | ConvertFrom-Json);
        runtime_log=$runtimeLog; frames=@(Get-ChildItem $outside -Filter 'release*.png' | Select-Object -ExpandProperty FullName);
        capture_warnings=@($captureLog -split "`n" | Where-Object { $_ -match '(?i)WARNING:' });
        actual_exe_gameplay_acceptance='PENDING MANUAL: opening, appraisal/trade, sale/pawn, save/restart, three-night ending, mirror/death/bankruptcy and corrupt-save UI';
        windows_dpi_matrix='PENDING MANUAL'; platform=[Environment]::OSVersion.VersionString;
        graphics=(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion)
    }
    Write-Utf8 "$outside/exe-smoke-report.json" ($report | ConvertTo-Json -Depth 10)
    Copy-Item "$outside/exe-smoke-report.json" (Join-Path (Split-Path $zip) 'exe-smoke-report.json')
    Write-Host "EXE STARTUP CHECK PASSED; full gameplay remains pending: $outside"
} finally {
    Set-Location $oldLocation
    $env:APPDATA = $oldAppData
}
