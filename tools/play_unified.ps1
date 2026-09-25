param(
    [ValidateSet('normal','knowledge','gramophone','camera','porcelain','bangle','pearl','watch','wealthy','wealthy-basic','wealthy-deep','wealthy-appraised','advertisement','introduction','contract','upgrade','fan','informed','ordinary','urgent','no-bench','intact','minor','major','stack','plaque','delivered','bedtime','call','dream','reunion','companion')][string]$Stage = 'normal',
    [ValidateSet('gramophone','camera','embroidery','gold_bangle','gold_watch','mantel_clock','pearl_necklace','jade_pendant','album','porcelain_vase','repeater','silver_set')][string]$Item = 'porcelain_vase',
    [ValidateSet('sound','mended','flawed')][string]$Condition = 'mended',
    [ValidateSet('intact','minor','major')][string]$Damage = 'minor',
    [ValidateSet('ordinary','hidden')][string]$Difficulty = 'hidden',
    [ValidateSet('natural','guide','bargain','overpriced','urgent','spotted','bluff','fault','firm','partial','fake-fault','exposed','engraving','gears')][string]$WatchCase = 'natural',
    [ValidateSet('','silk','factory','opera','antique','comprador')][string]$Holder = '',
    [ValidateSet('natural','good','lower','few','many','imitation','no-tools','partial','firm','exposed','guide')][string]$PearlCase = 'few',
    [ValidateSet('natural','good','lower','plated','repaired','matched','no-tools','partial','firm','exposed','guide')][string]$BangleCase = 'matched',
    [ValidateSet('natural','guide','bargain','overpriced','partial','firm','exposed','no-tools')][string]$PorcelainCase = 'natural',
    [ValidateSet('yuan','ming','qing','republic')][string]$Era = 'ming',
    [ValidateSet('rough','standard','fine')][string]$Craft = 'standard',
    [ValidateRange(1,2)][int]$Sample = 1,
    [ValidateSet('natural','good','haze','scratched','sticky','stuck','rebuilt','imitation','imitation-legacy','imitation-letters','imitation-extra','imitation-city','no-tools','partial','firm','exposed','guide')][string]$CameraCase = 'haze',
    [ValidateSet('natural','guide','good','wavering','stopping','rasping','muffled','worn-record','rebuilt','imitation','no-tools','partial','firm','exposed')][string]$GramophoneCase = 'good',
    [string]$GodotPath = '',
    [string]$Scene = 'res://scenes/start.tscn',
    [switch]$Wide,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $engineRelativePath = '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'
    $engineRoots = @($gameRoot)
    # Linked worktrees do not contain the main checkout's ignored .tools folder.
    # Resolve Git's own metadata instead of assuming a fixed drive or username.
    $gitMarker = Join-Path $gameRoot '.git'
    if (Test-Path -LiteralPath $gitMarker -PathType Leaf) {
        $gitPointer = Get-Content -LiteralPath $gitMarker -TotalCount 1
        if ($gitPointer -match '^gitdir:\s*(.+)$') {
            $gitDirectory = $Matches[1].Trim()
            if (-not [IO.Path]::IsPathRooted($gitDirectory)) { $gitDirectory = Join-Path $gameRoot $gitDirectory }
            $commonMarker = Join-Path $gitDirectory 'commondir'
            if (Test-Path -LiteralPath $commonMarker -PathType Leaf) {
                $commonDirectory = (Get-Content -LiteralPath $commonMarker -Raw).Trim()
                if (-not [IO.Path]::IsPathRooted($commonDirectory)) { $commonDirectory = Join-Path $gitDirectory $commonDirectory }
                $engineRoots += Split-Path -Parent ([IO.Path]::GetFullPath($commonDirectory))
            }
        }
    }
    $engineRoots += Split-Path -Parent (Split-Path -Parent $gameRoot)
    foreach ($engineRoot in $engineRoots) {
        $candidate = Join-Path $engineRoot $engineRelativePath
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $GodotPath = (Resolve-Path -LiteralPath $candidate).Path
            break
        }
    }
    if (-not $GodotPath) { $GodotPath = (Get-Command godot -ErrorAction SilentlyContinue).Source }
}
if (-not $GodotPath) { throw 'Godot 4.6.1 not found. Supply -GodotPath.' }
if ($Stage -eq 'knowledge') {
    & (Join-Path $PSScriptRoot 'play_fan_condition.ps1') -Stage knowledge -GodotPath $GodotPath -Wide:$Wide -Verify:$Verify
    exit $LASTEXITCODE
}
$previousAppData = $env:APPDATA
$precisionPreview = $Stage -in @('gramophone','camera','watch','pearl','bangle','porcelain','wealthy','wealthy-basic','wealthy-deep')
if ($Stage -eq 'porcelain') {
    $Item = 'porcelain_vase'
    if (-not $PSBoundParameters.ContainsKey('Damage')) { $Damage = 'intact' }
    if (-not $PSBoundParameters.ContainsKey('Difficulty')) { $Difficulty = 'ordinary' }
}
if ($Stage -eq 'gramophone') { $Item = 'gramophone'; if (-not $PSBoundParameters.ContainsKey('Damage')) { $Damage = 'intact' } }
if ($Stage -eq 'camera') { $Item = 'camera'; if (-not $PSBoundParameters.ContainsKey('Damage')) { $Damage = 'intact' } }
if ($Stage -eq 'watch') { $Item = 'gold_watch' }
if ($Stage -eq 'bangle') {
    $Item = 'gold_bangle'
    if (-not $PSBoundParameters.ContainsKey('Damage')) { $Damage = 'intact' }
    if (-not $PSBoundParameters.ContainsKey('Difficulty')) { $Difficulty = 'ordinary' }
}
if ($Stage -eq 'pearl') {
    $Item = 'pearl_necklace'
    if (-not $PSBoundParameters.ContainsKey('Damage')) { $Damage = 'intact' }
    if (-not $PSBoundParameters.ContainsKey('Difficulty')) { $Difficulty = 'ordinary' }
}
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
    $gameArgs = @('--path',$gameRoot,'--resolution',$(if ($Wide) { '1600x900' } else { '1280x720' }),$Scene)
    if ($Verify) { $gameArgs += @('--quit-after','90') }
    if ($precisionPreview) {
        $precisionLevel = @{ 'gramophone'='standard'; 'camera'='standard'; 'porcelain'='standard'; 'watch'='standard'; 'pearl'='standard'; 'bangle'='standard'; 'wealthy'='standard'; 'wealthy-basic'='basic'; 'wealthy-deep'='deep' }[$Stage]
        $gameArgs += @('--',"--precision-preview=$precisionLevel","--precision-item=$Item","--precision-condition=$Condition","--precision-damage=$Damage","--precision-difficulty=$Difficulty","--precision-watch-case=$WatchCase","--precision-holder=$Holder")
        if ($Stage -eq 'gramophone') { $gameArgs += "--precision-gramophone-case=$GramophoneCase" }
        if ($Stage -eq 'camera') { $gameArgs += "--precision-camera-case=$CameraCase" }
        if ($Stage -eq 'pearl') { $gameArgs += "--precision-pearl-case=$PearlCase" }
        if ($Stage -eq 'porcelain') { $gameArgs += @("--precision-porcelain-case=$PorcelainCase","--precision-era=$Era","--precision-craft=$Craft","--precision-sample=$Sample") }
        if ($Stage -eq 'bangle') { $gameArgs += "--precision-bangle-case=$BangleCase" }
        Write-Output 'Appraisal test preset: isolated, progress is not saved.'
    } elseif ($Stage -ne 'normal') { $gameArgs += @('--',"--unified-preview=$Stage") }
    $sceneVersions = @{ 'res://scenes/porcelain_v42.tscn'=42; 'res://scenes/lu_v43.tscn'=43; 'res://scenes/camera_v43.tscn'=43; 'res://scenes/start_camera_v43.tscn'=43; 'res://scenes/lu_v44.tscn'=44; 'res://scenes/start_lu_trade_v44.tscn'=44; 'res://scenes/start_gramophone_v44.tscn'=44; 'res://scenes/start_pawn_v45.tscn'=45 }
    $version = if ($Stage -eq 'normal' -or $precisionPreview) { if ($sceneVersions.ContainsKey($Scene)) { $sceneVersions[$Scene] } else { 46 } } elseif ($Stage -in @('wealthy-appraised','advertisement')) { 31 } else { 30 }
    Write-Output "Starting unified v${version}: $Stage"
    Invoke-CheckedGodot $gameArgs ('launch-' + $Stage + '.log')
    if ($Verify) { Write-Output "Verified unified v${version}: $Stage" }
} finally { $env:APPDATA = $previousAppData }
