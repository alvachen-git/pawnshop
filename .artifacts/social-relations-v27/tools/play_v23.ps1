param(
    [ValidateSet('new', 'commission', 'report', 'meeting')][string]$Stage = 'new',
    [string]$Godot = '',
    [switch]$Wide
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = Join-Path $projectRoot '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $Godot)) { throw '请用 -Godot 指定 Godot 4.6.1 的可执行文件。' }
Push-Location $projectRoot
$previousAppData = $env:APPDATA
try {
    $gameArgs = @('--path', $projectRoot, '--resolution', $(if ($Wide) {'1600x900'} else {'1280x720'}))
    if ($Stage -ne 'new') {
        # Both fixture generation and interactive previews use isolated test storage.
        $env:APPDATA = Join-Path $projectRoot '.godot/test-appdata'
        & $Godot --headless --editor --path $projectRoot --quit
        & $Godot --headless --path $projectRoot --script tests/run_investigation.gd -- fixtures-only
        if ($LASTEXITCODE -ne 0) { throw '快速试玩资料生成未通过验证。' }
        $gameArgs += @('--', "--investigation-preview=$Stage")
    }
    & $Godot @gameArgs
} finally { $env:APPDATA = $previousAppData; Pop-Location }
