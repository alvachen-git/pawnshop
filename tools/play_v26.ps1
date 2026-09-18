param(
    [ValidateSet('new', 'ready', 'apology', 'angry', 'evasive')][string]$Stage = 'new',
    [string]$Godot = '',
    [switch]$Wide,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    foreach ($candidate in @(
        (Join-Path $projectRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'),
        (Join-Path $projectRoot '../godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe')
    )) { if (Test-Path -LiteralPath $candidate) { $Godot = (Resolve-Path -LiteralPath $candidate).Path; break } }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) { throw 'Godot 4.6.1 not found. Use -Godot with the full executable path.' }
$previousAppData = $env:APPDATA
Push-Location $projectRoot
try {
    if ($Stage -ne 'new' -or $Check) { $env:APPDATA = Join-Path $projectRoot '.godot/test-appdata' }
    $logDir = Join-Path $projectRoot '.godot/qa/v26'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $importLog = Join-Path $logDir 'launch-import.log'
    $ErrorActionPreference = 'Continue'
    & $Godot --headless --editor --path $projectRoot --quit *> $importLog
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) { throw "Project import failed. See $importLog" }
    if ($Stage -ne 'new') {
        $stamp = Join-Path $logDir 'fixtures.stamp'
        $latest = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'core'), (Join-Path $projectRoot 'data'), (Join-Path $projectRoot 'tests') -Recurse -File |
            Where-Object { $_.Extension -in '.gd', '.json' } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        $fixture = Join-Path $logDir ($Stage + '.json')
        if (-not (Test-Path -LiteralPath $fixture) -or -not (Test-Path -LiteralPath $stamp) -or (Get-Item -LiteralPath $stamp).LastWriteTimeUtc -lt $latest.LastWriteTimeUtc) {
            Write-Host 'Preparing and verifying isolated v26 previews...'
            $testLog = Join-Path $logDir 'launch-fixtures.log'
            $ErrorActionPreference = 'Continue'
            & $Godot --headless --path $projectRoot --script tests/run_mirror_reunion.gd -- fixtures-only *> $testLog
            $ErrorActionPreference = 'Stop'
            if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $testLog -Pattern 'SCRIPT ERROR|FAIL ' -Quiet)) { throw "Preview validation failed. See $testLog" }
            Set-Content -LiteralPath $stamp -Value 'v26 verified' -Encoding Ascii
        }
    }
    $gameArgs = @('--path', $projectRoot, 'res://scenes/start_v26.tscn', '--resolution', $(if ($Wide) { '1600x900' } else { '1280x720' }))
    if ($Check) { $gameArgs += @('--headless', '--quit-after', '3') }
    if ($Stage -ne 'new') { $gameArgs += @('--', "--mirror-reunion-preview=$Stage") }
    $ErrorActionPreference = 'Continue'
    Write-Host "Starting v26 ($Stage)..."
    if ($Check) {
        $gameLog = Join-Path $logDir ('launch-' + $Stage + '.log')
        & $Godot @gameArgs *> $gameLog
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $gameLog -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) { throw "Launch check failed. See $gameLog" }
    } else { & $Godot @gameArgs }
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) { throw 'Godot exited with an error.' }
} finally {
    $env:APPDATA = $previousAppData
    Pop-Location
}
