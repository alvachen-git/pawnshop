param(
    [ValidateSet('normal', 'upgrade', 'fan')][string]$Stage = 'normal',
    [string]$GodotPath = '',
    [switch]$Wide,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    foreach ($candidate in @(
        (Join-Path $gameRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'),
        (Join-Path $gameRoot '../../.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe')
    )) {
        if (Test-Path -LiteralPath $candidate) { $GodotPath = (Resolve-Path -LiteralPath $candidate).Path; break }
    }
}
if (-not $GodotPath) { throw 'Godot 4.6.1 not found. Supply -GodotPath.' }
$previousAppData = $env:APPDATA
$env:APPDATA = Join-Path $gameRoot ('.godot/play-data/unified-' + $Stage)
$logDir = Join-Path $gameRoot '.godot/qa/appraisal'
New-Item -ItemType Directory -Force $env:APPDATA,$logDir | Out-Null
try {
    $ErrorActionPreference = 'Continue'
    & $GodotPath --headless --editor --path $gameRoot --quit *> (Join-Path $logDir 'launch-import.log')
    $importExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($importExit -ne 0 -or (Select-String (Join-Path $logDir 'launch-import.log') -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) { throw 'Project import failed. See .godot/qa/appraisal/launch-import.log.' }
    if ($Stage -ne 'normal') {
        $fixture = Join-Path $gameRoot '.godot/qa/shop-appraisal/fan-sound.json'
        $stamp = Join-Path $gameRoot '.godot/qa/shop-appraisal/verified.stamp'
        $latest = Get-ChildItem (Join-Path $gameRoot 'core'),(Join-Path $gameRoot 'data'),(Join-Path $gameRoot 'tests/shop_appraisal.gd') -Recurse -File |
            Where-Object { $_.Extension -in '.gd','.json' } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if (-not (Test-Path $fixture) -or -not (Test-Path $stamp) -or (Get-Item $stamp).LastWriteTimeUtc -lt $latest.LastWriteTimeUtc) {
            $ErrorActionPreference = 'Continue'
            & $GodotPath --headless --path $gameRoot --script tests/shop_appraisal.gd *> (Join-Path $logDir 'launch-fixtures.log')
            $fixtureExit = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            $fixtureLog = Get-Content (Join-Path $logDir 'launch-fixtures.log') -Raw
            if ($fixtureExit -ne 0 -or $fixtureLog -match 'SCRIPT ERROR|Parse Error|FAIL ' -or $fixtureLog -notmatch '0 failures') { throw 'Preview validation failed. See .godot/qa/appraisal/launch-fixtures.log.' }
            Set-Content -LiteralPath $stamp -Value 'verified v27' -Encoding Ascii
        }
    }
    $gameArgs = @('--path', $gameRoot, '--resolution', $(if ($Wide) { '1600x900' } else { '1280x720' }), 'res://scenes/start_v27.tscn')
    if ($Verify) { $gameArgs += @('--quit-after','90') }
    if ($Stage -ne 'normal') {
        $previewStage = if ($Stage -eq 'upgrade') { 'upgrade' } else { 'fan-sound' }
        $gameArgs += @('--', "--appraisal-preview=$previewStage")
    }
    $launchId = [Guid]::NewGuid().ToString('N').Substring(0, 12)
    $stdout = Join-Path $logDir ('launch-' + $Stage + '-' + $launchId + '.log')
    Write-Output "Starting unified game: $Stage"
    # Native invocation also works in Windows PowerShell 5 when the inherited
    # environment contains both Path and PATH (Start-Process rejects that).
    $ErrorActionPreference = 'Continue'
    & $GodotPath @gameArgs 2>&1 | Out-File -LiteralPath $stdout -Encoding utf8 -ErrorAction Stop
    $gameExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($gameExit -ne 0 -or (Select-String $stdout -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) { throw "Launch failed: $Stage. See $stdout" }
    if ($Verify) { Write-Output "Verified unified launch: $Stage" }
} finally { $env:APPDATA = $previousAppData }
