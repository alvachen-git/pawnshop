param(
    [ValidateSet('normal', 'upgrade', 'fan', 'informed', 'ordinary', 'urgent', 'no-bench', 'intact', 'minor', 'major', 'stack', 'knowledge')][string]$Stage = 'normal',
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
if ($Stage -ne 'normal') { $env:APPDATA = Join-Path $gameRoot ('.godot/play-data/fan-preview-v29-' + $Stage) }
$logDir = Join-Path $gameRoot '.godot/qa/appraisal'
New-Item -ItemType Directory -Force $logDir | Out-Null
if ($Stage -ne 'normal') { New-Item -ItemType Directory -Force $env:APPDATA | Out-Null }
try {
    $ErrorActionPreference = 'Continue'
    & $GodotPath --headless --editor --path $gameRoot --quit *> (Join-Path $logDir 'launch-import.log')
    $importExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($importExit -ne 0 -or (Select-String (Join-Path $logDir 'launch-import.log') -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) { throw 'Project import failed. See .godot/qa/appraisal/launch-import.log.' }
    if ($Stage -ne 'normal') {
        $fixture = Join-Path $gameRoot '.godot/qa/fan-condition/fan-sound.json'
        $stamp = Join-Path $gameRoot '.godot/qa/fan-condition/verified.stamp'
        $latest = Get-ChildItem (Join-Path $gameRoot 'core'),(Join-Path $gameRoot 'data'),(Join-Path $gameRoot 'tests/fan_condition.gd') -Recurse -File |
            Where-Object { $_.Extension -in '.gd','.json' } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if (-not (Test-Path $fixture) -or -not (Test-Path $stamp) -or (Get-Item $stamp).LastWriteTimeUtc -lt $latest.LastWriteTimeUtc) {
            $ErrorActionPreference = 'Continue'
            & $GodotPath --headless --path $gameRoot --script tests/fan_condition.gd *> (Join-Path $logDir 'launch-fixtures.log')
            $fixtureExit = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            $fixtureLog = Get-Content (Join-Path $logDir 'launch-fixtures.log') -Raw
            if ($fixtureExit -ne 0 -or $fixtureLog -match 'SCRIPT ERROR|Parse Error|FAIL ' -or $fixtureLog -notmatch '0 failures') { throw 'Preview validation failed. See .godot/qa/appraisal/launch-fixtures.log.' }
            Set-Content -LiteralPath $stamp -Value 'verified v29' -Encoding Ascii
        }
    }
    if ($Stage -eq 'knowledge') {
        $knowledgeFixture = Join-Path $gameRoot '.godot/qa/fan-condition/knowledge-before.json'
        $knowledgeStamp = Join-Path $gameRoot '.godot/qa/fan-condition/knowledge.stamp'
        $knowledgeTest = Get-Item (Join-Path $gameRoot 'tests/shop_knowledge.gd')
        if (-not (Test-Path $knowledgeFixture) -or -not (Test-Path $knowledgeStamp) -or (Get-Item $knowledgeStamp).LastWriteTimeUtc -lt $latest.LastWriteTimeUtc -or (Get-Item $knowledgeStamp).LastWriteTimeUtc -lt $knowledgeTest.LastWriteTimeUtc) {
            $ErrorActionPreference = 'Continue'
            & $GodotPath --headless --path $gameRoot --script tests/shop_knowledge.gd *> (Join-Path $logDir 'launch-knowledge-fixtures.log')
            $knowledgeExit = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            $knowledgeLog = Get-Content (Join-Path $logDir 'launch-knowledge-fixtures.log') -Raw
            if ($knowledgeExit -ne 0 -or $knowledgeLog -match 'SCRIPT ERROR|Parse Error|FAIL ' -or $knowledgeLog -notmatch '0 failures') { throw 'Knowledge preview validation failed. See .godot/qa/appraisal/launch-knowledge-fixtures.log.' }
            Set-Content -LiteralPath $knowledgeStamp -Value 'verified knowledge v29' -Encoding Ascii
        }
    }
    $scene = if ($Stage -eq 'normal') { 'res://scenes/start.tscn' } else { 'res://scenes/start_fan_condition_v29.tscn' }
    $gameArgs = @('--path', $gameRoot, '--resolution', $(if ($Wide) { '1600x900' } else { '1280x720' }), $scene)
    if ($Verify) { $gameArgs += @('--quit-after','90') }
    if ($Stage -ne 'normal') {
        $previewStage = if ($Stage -eq 'knowledge') { 'knowledge-before' } elseif ($Stage -eq 'upgrade') { 'upgrade' } elseif ($Stage -eq 'fan') { 'fan-sound' } elseif ($Stage -in @('informed','ordinary','urgent')) { $Stage + '-ready' } else { $Stage }
        $gameArgs += @('--', "--condition-preview=$previewStage")
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
