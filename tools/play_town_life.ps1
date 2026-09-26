param(
    [ValidateSet('normal','porter','musician','washerwoman','soldier','goods','military')][string]$Stage = 'normal',
    [ValidateSet('','silver_earrings','item_silver_earrings','abacus','copper_handwarmer','kerosene_lamp','leather_suitcase','erhu','padded_vest','item_abacus','item_copper_handwarmer','item_kerosene_lamp','item_leather_suitcase','item_erhu','item_padded_vest')][string]$Item = '',
    [ValidateSet('sound','mended','worn','flawed')][string]$Condition = 'sound',
    [ValidateSet(-20,0,20)][int]$Military = 0,
    [string]$GodotPath = '',
    [switch]$Wide,
    [switch]$Legacy,
    [ValidateSet(48,49,50)][int]$Version = 50,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
$effectiveVersion = if ($Legacy) { 48 } else { $Version }
if ($effectiveVersion -eq 50 -and $Item -in @('abacus','item_abacus')) { throw 'Abacus was replaced. Use -Item silver_earrings, or -Version 49 for older saves.' }
if ($effectiveVersion -lt 50 -and $Item -in @('silver_earrings','item_silver_earrings')) { throw 'Silver earrings require -Version 50.' }
if (-not $GodotPath) {
    $candidates = @(
        (Join-Path $gameRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'),
        (Join-Path $env:USERPROFILE 'Documents/ChatGPT/pawnbroker/.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe')
    )
    $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $GodotPath) { $GodotPath = (Get-Command godot -ErrorAction SilentlyContinue).Source }
}
if (-not $GodotPath) { throw 'Godot 4.6 is required. Pass -GodotPath to its executable.' }
$qaRoot = Join-Path $gameRoot '.godot/qa/town-life'
New-Item -ItemType Directory -Path $qaRoot -Force | Out-Null
# Windows PowerShell 5.1 promotes redirected native stderr to ErrorRecord.
# Godot warnings must finish normally; use exit status and script errors to fail.
function Invoke-TownLifeGodot([string[]]$EngineArguments, [string]$LogName) {
    $logPath = Join-Path $qaRoot $LogName
    $ErrorActionPreference = 'Continue'
    & $GodotPath @EngineArguments *> $logPath
    $engineExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $body = Get-Content -LiteralPath $logPath -Raw
    if ($engineExit -ne 0 -or $body -match 'SCRIPT ERROR|Parse Error') {
        throw "Godot failed (exit $engineExit). See $logPath"
    }
}
$previousAppData = $env:APPDATA
try {
    if ($Stage -ne 'normal') {
        $env:APPDATA = Join-Path $qaRoot 'preview-profile'
        New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    }
    Invoke-TownLifeGodot @('--headless','--path',$gameRoot,'--editor','--import','--quit') 'import.log'
    $gameArgs = @('--path',$gameRoot,'--rendering-method','gl_compatibility','--resolution',$(if($Wide){'1600x900'}else{'1280x720'}))
    if ($Verify) { $gameArgs += @('--quit-after','90') }
    if ($Stage -eq 'normal') { $gameArgs += $(if($effectiveVersion -eq 48){'res://scenes/town_life_start.tscn'}else{"res://scenes/town_life_v${effectiveVersion}_start.tscn"}) }
    else { $gameArgs += @('--script','res://tools/town_life_preview.gd','--',"--town-stage=$Stage","--town-version=$effectiveVersion","--town-legacy=$($Legacy.IsPresent.ToString().ToLower())","--town-item=$Item","--town-condition=$Condition","--town-military=$Military","--town-wide=$($Wide.IsPresent.ToString().ToLower())") }
    Invoke-TownLifeGodot $gameArgs ('launch-' + $Stage + '.log')
    exit 0
} finally { $env:APPDATA = $previousAppData }
