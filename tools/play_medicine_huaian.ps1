param(
    [ValidateSet('normal','first','final','report','saved','bereaved')][string]$Stage = 'normal',
    [string]$Item = 'item_luxury_embroidery',
    [string]$GodotPath = '',
    [switch]$Wide,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $candidates = @(
        (Join-Path $gameRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'),
        (Join-Path $env:USERPROFILE 'Documents/ChatGPT/pawnbroker/.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe')
    )
    $GodotPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $GodotPath) { $GodotPath = (Get-Command godot -ErrorAction SilentlyContinue).Source }
}
if (-not $GodotPath) { throw 'Godot 4.6 is required. Pass -GodotPath to its executable.' }
$qaRoot = Join-Path $gameRoot '.godot/qa/medicine-huaian'
New-Item -ItemType Directory -Path $qaRoot -Force | Out-Null
# Windows PowerShell 5.1 promotes redirected native stderr to ErrorRecord.
# Godot warnings must finish normally; use exit status and script errors to fail.
function Invoke-SpecialGuestsGodot([string[]]$EngineArguments, [string]$LogName) {
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
    Invoke-SpecialGuestsGodot @('--headless','--path',$gameRoot,'--editor','--import','--quit') 'import.log'
    $gameArgs = @('--path',$gameRoot,'--rendering-method','gl_compatibility','--resolution',$(if($Wide){'1600x900'}else{'1280x720'}))
    if ($Verify) { $gameArgs += @('--quit-after','90') }
    if ($Stage -eq 'normal') { $gameArgs += 'res://scenes/start_medicine_huaian_v47.tscn' }
    else { $gameArgs += @('--script','res://tools/medicine_preview.gd','--',"--special-stage=$Stage","--special-item=$Item","--special-wide=$($Wide.IsPresent.ToString().ToLower())") }
    Invoke-SpecialGuestsGodot $gameArgs ('launch-' + $Stage + '.log')
    exit 0
} finally { $env:APPDATA = $previousAppData }
