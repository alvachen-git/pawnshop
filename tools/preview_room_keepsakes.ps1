param(
    [switch]$Play,
    [ValidateSet(1280, 1600)][int]$Width = 1600,
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
$keepsakesProject = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $keepsakesAncestor = $keepsakesProject
    while ($keepsakesAncestor) {
        $keepsakesCandidate = Join-Path $keepsakesAncestor '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'
        if (Test-Path -LiteralPath $keepsakesCandidate) { $GodotPath = $keepsakesCandidate; break }
        $keepsakesParent = Split-Path -Parent $keepsakesAncestor
        if ($keepsakesParent -eq $keepsakesAncestor) { break }
        $keepsakesAncestor = $keepsakesParent
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4.6.1 was not found. Pass -GodotPath with the executable path.'
}
$keepsakesPreviousAppData = $env:APPDATA
$env:APPDATA = Join-Path $keepsakesProject '.artifacts/keepsakes-preview/user'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
try {
    if ($Play) {
        & $GodotPath --path $keepsakesProject
    } else {
        $keepsakesOptions = @('--path', $keepsakesProject, '--script', 'res://tests/room_keepsakes_ui.gd', '--', 'interactive')
        if ($Width -eq 1600) { $keepsakesOptions += 'wide' }
        & $GodotPath @keepsakesOptions
    }
} finally {
    $env:APPDATA = $keepsakesPreviousAppData
}
