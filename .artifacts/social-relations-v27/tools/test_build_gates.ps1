param([Parameter(Mandatory=$true)][string]$OutputDir)
. "$PSScriptRoot/windows_common.ps1"
$output = [IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force -Path $output | Out-Null
$shell = (Get-Process -Id $PID).Path
$cases = @(
    @{name='zero-exit-script-error'; command='Write-Output SCRIPT_ERROR_MARKER; exit 0'; marker=''; replace=$true},
    @{name='nonzero-exit'; command='exit 9'; marker=''; replace=$false},
    @{name='failed-assertion'; command='Write-Output FAIL:; exit 0'; marker=''; replace=$false},
    @{name='missing-success-summary'; command='Write-Output incomplete; exit 0'; marker='TESTS PASSED'; replace=$false}
)
foreach ($case in $cases) {
    $command = $case.command
    if ($case.replace) { $command = 'Write-Output ERROR:; exit 0' }
    $rejected = $false
    try { Invoke-GodotChecked $shell @('-NoProfile','-Command',$command) "$output/$($case.name).log" $case.marker | Out-Null }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Gate failed to reject: $($case.name)" }
    Write-Host "BUILD GATE PASS: $($case.name)"
}
$timedOut = $false
try { Invoke-GodotChecked $shell @('-NoProfile','-Command','Start-Sleep -Seconds 10') "$output/timeout.log" '' 1 | Out-Null }
catch { $timedOut = $_.Exception.Message -match 'Timed out' }
if (-not $timedOut) { throw 'Timeout gate failed.' }
Write-Host 'BUILD GATE PASS: child timeout'
# A conditional English warning is not an uppercase assertion failure.
Invoke-GodotChecked $shell @('-NoProfile','-Command','Write-Output WARNING:will-fail-if-full; exit 0') "$output/warning-classification.log" 'WARNING:' | Out-Null
Write-Host 'BUILD GATE PASS: retained warning is not a failed assertion'
