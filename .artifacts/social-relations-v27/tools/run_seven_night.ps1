param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [ValidateRange(0,2147483647)][int]$Seed,
    [switch]$LogPlan
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$gameArguments = @('--path', $projectRoot, 'res://scenes/seven_night.tscn')
$extraArguments = @()
if ($PSBoundParameters.ContainsKey('Seed')) { $extraArguments += "--seed=$Seed" }
if ($LogPlan) { $extraArguments += '--log-plan' }
if ($extraArguments.Count -gt 0) { $gameArguments += @('--') + $extraArguments }
& $enginePath @gameArguments
if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
