param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [ValidateRange(0,2147483647)][int]$Seed = 42
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
& $enginePath --path $projectRoot 'res://scenes/four_night.tscn' -- "--seed=$Seed"
if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
