param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [Parameter(Mandatory=$true)][string]$OutputDir
)
. "$PSScriptRoot/windows_common.ps1"
$root = Split-Path $PSScriptRoot -Parent
$engine = Get-CheckedGodot $GodotPath
$output = [IO.Path]::GetFullPath($OutputDir)
if (Test-Path (Join-Path $output 'results.json')) { throw 'Choose a fresh test output directory.' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$oldAppData = $env:APPDATA
$oldExpected = $env:PAWNSHOP_TEST_APPDATA
$results = [Collections.Generic.List[object]]::new()
function Run-Test([string]$Name, [string]$Script, [string[]]$UserArgs = @(), [bool]$Headless = $true) {
    $arguments = @('--path', $root, '--script', "res://tests/$Script")
    if ($Headless) { $arguments = @('--headless') + $arguments }
    if (@($UserArgs).Count -gt 0) { $arguments += @('--') + $UserArgs }
    $log = Invoke-GodotChecked $engine $arguments (Join-Path $output "$Name.log") '(?im)TESTS PASSED|0 failures|PASS=true|M8A ENV PASS|M8A COPY PASS'
    $summary = @($log -split "`n" | Where-Object { $_ -match 'TESTS PASSED|assertions,|passes,|PASS=true|M8A ENV PASS|M8A COPY PASS' })
    $results.Add(@{ name=$Name; summary=$summary; passed=$true })
}
try {
    $env:APPDATA = Join-Path $output 'appdata'
    $env:PAWNSHOP_TEST_APPDATA = $env:APPDATA
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    Invoke-GodotChecked $engine @('--headless','--editor','--path',$root,'--quit') (Join-Path $output 'import.log') | Out-Null
    Run-Test 'environment' 'm8a_environment.gd'
    Run-Test 'font' 'm8a_font.gd'
    Run-Test 'core' 'run_all.gd'
    foreach ($suite in @('ui_smoke','scene_navigation_ui_smoke','m2_ui_smoke','m3_ui_smoke','m4_ui_smoke','m5_ui_smoke','art03_extension_ui_smoke')) {
        Run-Test $suite "$suite.gd" @() $false
    }
    foreach ($wide in @($false,$true)) {
        $size = if ($wide) { '1600x900' } else { '1280x720' }
        $sizeArgs = @(if ($wide) { 'wide' })
        Run-Test "m7-$size" 'm7_ui_smoke.gd' $sizeArgs $false
        Run-Test "m6-production-$size" 'm6_ui_smoke.gd' (@('production') + $sizeArgs) $false
        Run-Test "accounts-$size" 'art03_ui_smoke.gd' $sizeArgs $false
        Run-Test "debt-production-$size" 'art03_debt_ui_smoke.gd' (@('production') + $sizeArgs) $false
    }
    foreach ($mode in @('write','resume','read')) {
        Run-Test "m7-process-$mode" 'm7_checkpoint_process.gd' @($mode)
        if ($mode -eq 'write') { Run-Test 'v7-copy-compatibility' 'm8a_save_copy.gd' }
    }
    foreach ($mode in @('write_debt','resume_bankrupt','read_bankrupt','write_mirror','resume_death','read_death')) {
        Run-Test "m6-process-$mode" 'm6_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('warning','death','restart','archive')) {
        Run-Test "m5-process-$mode" 'm5_checkpoint_process.gd' @($mode)
    }
    # Screenshots are produced by the existing real-viewport tests, not by release EXE.
    if (Test-Path "$root/.godot/qa") { Copy-Item "$root/.godot/qa" (Join-Path $output 'screenshots') -Recurse }
    Write-Utf8 (Join-Path $output 'results.json') (ConvertTo-Json -InputObject @($results.ToArray()) -Depth 10)
    Write-Host "WINDOWS SOURCE VALIDATION PASSED: $output"
} finally {
    $env:APPDATA = $oldAppData
    $env:PAWNSHOP_TEST_APPDATA = $oldExpected
}
