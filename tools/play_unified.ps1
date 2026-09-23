param(
    [ValidateSet('normal','watch','wealthy','wealthy-basic','wealthy-deep','wealthy-appraised','advertisement','introduction','contract','upgrade','fan','informed','ordinary','urgent','no-bench','intact','minor','major','stack','plaque','delivered','bedtime','call','dream','reunion','companion')][string]$Stage = 'normal',
    [ValidateSet('embroidery','gold_bangle','gold_watch','mantel_clock','pearl_necklace','jade_pendant','album','porcelain_vase','repeater','silver_set')][string]$Item = 'porcelain_vase',
    [ValidateSet('sound','mended','flawed')][string]$Condition = 'mended',
    [ValidateSet('intact','minor','major')][string]$Damage = 'minor',
    [ValidateSet('ordinary','hidden')][string]$Difficulty = 'hidden',
    [ValidateSet('natural','guide','bargain','overpriced','urgent','spotted','bluff','fault','firm','partial','fake-fault','exposed','engraving','gears')][string]$WatchCase = 'natural',
    [string]$GodotPath = '',
    [switch]$Wide,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $candidate = Join-Path $gameRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'
    if (Test-Path -LiteralPath $candidate) { $GodotPath = (Resolve-Path -LiteralPath $candidate).Path }
    else { $GodotPath = (Get-Command godot -ErrorAction SilentlyContinue).Source }
}
if (-not $GodotPath) { throw 'Godot 4.6.1 not found. Supply -GodotPath.' }
$previousAppData = $env:APPDATA
$precisionPreview = $Stage -in @('watch','wealthy','wealthy-basic','wealthy-deep')
if ($Stage -eq 'watch') { $Item = 'gold_watch' }
$logDir = Join-Path $gameRoot ('.godot/qa/unified-launch/' + (Get-Date -Format 'yyyyMMdd-HHmmss-ffff') + '-' + $PID)
New-Item -ItemType Directory -Force $logDir | Out-Null
# Normal play shares the editor's save library. QA and previews are isolated.
if ($Stage -ne 'normal' -or $Verify) {
    $env:APPDATA = Join-Path $gameRoot ('.godot/play-data/unified-' + $Stage)
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
}
function Invoke-CheckedGodot([string[]]$GameArgs, [string]$LogName, [switch]$TestRun) {
    $log = Join-Path $logDir $LogName
    $ErrorActionPreference = 'Continue'
    & $GodotPath @GameArgs *> $log
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $body = Get-Content -LiteralPath $log -Raw
    if ($code -ne 0 -or $body -match 'SCRIPT ERROR|Parse Error|FAIL ' -or ($TestRun -and $body -notmatch '0 failures')) {
        throw "Validation failed. See $log"
    }
}
try {
    Invoke-CheckedGodot @('--headless','--editor','--path',$gameRoot,'--quit') 'import.log'
    if ($Stage -ne 'normal' -and -not $precisionPreview) {
        $test = if ($Stage -in @('wealthy','wealthy-appraised')) { 'wealthy_journey' }
            elseif ($Stage -eq 'advertisement') { 'wealthy_customers' }
            elseif ($Stage -in @('plaque','delivered')) { 'unified_social' }
            elseif ($Stage -in @('bedtime','call','dream','reunion')) { 'unified_story' }
            elseif ($Stage -eq 'companion') { 'unified_companion' }
            else { 'unified_appraisal' }
        # Regenerate and verify from real play, so previews never use stale rules.
        Invoke-CheckedGodot @('--headless','--path',$gameRoot,'--script',"res://tests/$test.gd") "$test.log" -TestRun
    }
    $gameArgs = @('--path',$gameRoot,'--resolution',$(if ($Wide) { '1600x900' } else { '1280x720' }),'res://scenes/start.tscn')
    if ($Verify) { $gameArgs += @('--quit-after','90') }
    if ($precisionPreview) {
        $precisionLevel = @{ 'watch'='standard'; 'wealthy'='standard'; 'wealthy-basic'='basic'; 'wealthy-deep'='deep' }[$Stage]
        $gameArgs += @('--',"--precision-preview=$precisionLevel","--precision-item=$Item","--precision-condition=$Condition","--precision-damage=$Damage","--precision-difficulty=$Difficulty","--precision-watch-case=$WatchCase")
        Write-Output 'Appraisal test preset: isolated, progress is not saved.'
    } elseif ($Stage -ne 'normal') { $gameArgs += @('--',"--unified-preview=$Stage") }
    $version = if ($Stage -eq 'normal' -or $precisionPreview) { 37 } elseif ($Stage -in @('wealthy-appraised','advertisement')) { 31 } else { 30 }
    Write-Output "Starting unified v${version}: $Stage"
    Invoke-CheckedGodot $gameArgs ('launch-' + $Stage + '.log')
    if ($Verify) { Write-Output "Verified unified v${version}: $Stage" }
} finally { $env:APPDATA = $previousAppData }
