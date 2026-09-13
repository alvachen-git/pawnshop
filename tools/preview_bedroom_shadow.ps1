param(
    [switch]$Play,
    [ValidateSet(1280, 1600)][int]$Width = 1600,
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
$shadowProject = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $shadowAncestor = $shadowProject
    while ($shadowAncestor) {
        $shadowCandidate = Join-Path $shadowAncestor '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'
        if (Test-Path -LiteralPath $shadowCandidate) { $GodotPath = $shadowCandidate; break }
        $shadowParent = Split-Path -Parent $shadowAncestor
        if ($shadowParent -eq $shadowAncestor) { break }
        $shadowAncestor = $shadowParent
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4.6.1 was not found. Pass -GodotPath with the executable path.'
}
$shadowPreviousAppData = $env:APPDATA
$env:APPDATA = Join-Path $shadowProject '.artifacts/shadow-preview/user'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
try {
    & $GodotPath --headless --path $shadowProject --editor --import *> (Join-Path $shadowProject '.artifacts/shadow-preview/import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Project import failed. See .artifacts/shadow-preview/import.log.' }
    if ($Play) {
        & $GodotPath --path $shadowProject
    } else {
        Write-Host 'Preparing an isolated third-night checkpoint from the actual game flow...'
        & $GodotPath --headless --path $shadowProject --script res://tests/run_bedroom_shadow.gd -- preview-fixture *> (Join-Path $shadowProject '.artifacts/shadow-preview/fixture.log')
        if ($LASTEXITCODE -ne 0) { throw 'Preview setup failed. See .artifacts/shadow-preview/fixture.log.' }
        $shadowOptions = @('--path', $shadowProject, '--script', 'res://tests/bedroom_shadow_ui.gd', '--', 'interactive')
        if ($Width -eq 1600) { $shadowOptions += 'wide' }
        & $GodotPath @shadowOptions
    }
} finally {
    $env:APPDATA = $shadowPreviousAppData
}
