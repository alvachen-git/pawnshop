param(
    [switch]$Play,
    [ValidateSet(1280, 1600)][int]$Width = 1600,
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
$lampProject = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $lampAncestor = $lampProject
    while ($lampAncestor) {
        $lampCandidate = Join-Path $lampAncestor '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'
        if (Test-Path -LiteralPath $lampCandidate) { $GodotPath = $lampCandidate; break }
        $lampParent = Split-Path -Parent $lampAncestor
        if ($lampParent -eq $lampAncestor) { break }
        $lampAncestor = $lampParent
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4.6.1 was not found. Pass -GodotPath with the executable path.'
}
# Both review and full-game test use one isolated local save library.
$lampPreviousAppData = $env:APPDATA
$env:APPDATA = Join-Path $lampProject '.artifacts/life-lamp-preview/user'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
try {
    if ($Play) {
        & $GodotPath --path $lampProject
    } else {
        $lampOptions = @('--path', $lampProject, '--script', 'res://tests/life_lamp_ui.gd', '--', 'interactive', '--seed=42')
        if ($Width -eq 1600) { $lampOptions += 'wide' }
        & $GodotPath @lampOptions
    }
} finally {
    $env:APPDATA = $lampPreviousAppData
}
