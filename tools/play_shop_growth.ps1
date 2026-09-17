param(
    [ValidateSet('normal', 'preparation', 'closed', 'buyer', 'facilities')][string]$Stage = 'normal',
    [ValidateRange(0,3)][int]$Level = 0,
    [int]$Seed = -1,
    [switch]$Wide,
    [switch]$Verify,
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
$gameRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $gameRoot '../..'))
$engine = $GodotPath
if (-not $engine) { $engine = Join-Path $gameRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $engine)) { $engine = Join-Path $sourceRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $engine)) { throw "Missing local Godot 4.6.1 engine: $engine" }
$env:APPDATA = Join-Path $gameRoot ('.godot/play-data/' + $(if ($Stage -eq 'normal') { 'normal' } else { 'preview-' + $Stage }))
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$logRoot = Join-Path $gameRoot 'docs/qa/shop-growth'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
if (-not (Test-Path (Join-Path $gameRoot '.godot/global_script_class_cache.cfg'))) {
    & $engine --headless --editor --path $gameRoot --quit *> (Join-Path $logRoot 'launch-import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed. See launch-import.log.' }
}
if ($Stage -notin @('normal', 'facilities')) {
    & $engine --headless --path $gameRoot --script tests/shop_growth_fixtures.gd *> (Join-Path $logRoot 'launch-fixtures.log')
    $fixtureLog = Get-Content (Join-Path $logRoot 'launch-fixtures.log') -Raw
    if ($LASTEXITCODE -ne 0 -or $fixtureLog -match 'SCRIPT ERROR|FAIL ' -or $fixtureLog -notmatch '0 failures') { throw 'Preview verification failed. See launch-fixtures.log.' }
}
$gameArgs = @('--path', ('"' + $gameRoot + '"'), '--resolution', $(if ($Wide) { '1600x900' } else { '1280x720' }))
if ($Stage -eq 'facilities') { $gameArgs += 'res://scenes/facilities_preview.tscn' } else { $gameArgs += 'res://scenes/start_shop_growth.tscn' }
if ($Verify) { $gameArgs += @('--quit-after', '90') }
$gameArgs += '--'
if ($Stage -notin @('normal', 'facilities')) { $gameArgs += '--growth-preview=' + $Stage }
if ($Stage -eq 'facilities') { $gameArgs += '--facility-level=' + $Level }
if ($Seed -ge 0) { $gameArgs += '--seed=' + $Seed }
$process = Start-Process -FilePath $engine -ArgumentList $gameArgs -WorkingDirectory $gameRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot ('launch-' + $Stage + '.log')) -RedirectStandardError (Join-Path $logRoot ('launch-' + $Stage + '-stderr.log'))
if ($Verify) {
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Launch failed: $Stage" }
    $stderrText = Get-Content (Join-Path $logRoot ('launch-' + $Stage + '-stderr.log')) -Raw
    if ($stderrText -match 'SCRIPT ERROR|Parse Error') { throw "Launch script error: $Stage" }
    Write-Output "Verified launch: $Stage; isolated saves: $env:APPDATA"
} else { Write-Output "Game started: $Stage; isolated saves: $env:APPDATA" }
