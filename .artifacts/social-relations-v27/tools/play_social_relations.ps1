param(
    [ValidateSet('normal','introduction','preparation','closure','supply','claim','respected','disliked','delivery','near_plaque','plaque','intimidation','cotton')][string]$Stage = 'normal',
    [int]$Seed = -1,
    [switch]$Wide,
    [switch]$Verify
)
$ErrorActionPreference = 'Stop'
$socialGame = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$socialWorkspace = [IO.Path]::GetFullPath((Join-Path $socialGame '../..'))
$socialEngine = Join-Path $socialWorkspace '.tools/godot-4.6.1/Godot_v4.6.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $socialEngine)) { throw 'Local Godot 4.6.1 engine is missing.' }
$env:APPDATA = Join-Path $socialGame ('.godot/play-data/' + $Stage)
$socialLogs = Join-Path $socialGame '.godot/qa/social-relations'
New-Item -ItemType Directory -Path $env:APPDATA,$socialLogs -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $socialGame '.godot/global_script_class_cache.cfg'))) {
    $ErrorActionPreference = 'Continue'
    & $socialEngine --headless --editor --path $socialGame --quit *> (Join-Path $socialLogs 'launch-import.log')
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0 -or (Get-Content (Join-Path $socialLogs 'launch-import.log') -Raw) -match 'SCRIPT ERROR|Parse Error') { throw 'Project import failed. See launch-import.log.' }
}
if ($Stage -ne 'normal') {
    $ErrorActionPreference = 'Continue'
    & $socialEngine --headless --path $socialGame --script tests/social_v27_fixtures.gd *> (Join-Path $socialLogs 'launch-fixtures.log')
    $ErrorActionPreference = 'Stop'
    $socialFixtureOutput = Get-Content (Join-Path $socialLogs 'launch-fixtures.log') -Raw
    if ($LASTEXITCODE -ne 0 -or $socialFixtureOutput -match 'SCRIPT ERROR|FAIL ' -or $socialFixtureOutput -notmatch '0 failures') { throw 'Scenario validation failed. See launch-fixtures.log.' }
}
$socialArgs = @('--path', ('"' + $socialGame + '"'), '--resolution', $(if ($Wide) { '1600x900' } else { '1280x720' }))
if ($Verify) { $socialArgs += @('--quit-after','60') }
$socialArgs += '--'
if ($Stage -ne 'normal') { $socialArgs += '--social-preview=' + $Stage }
if ($Seed -ge 0) { $socialArgs += '--seed=' + $Seed }
$socialProcess = Start-Process -FilePath $socialEngine -ArgumentList $socialArgs -WorkingDirectory $socialGame -WindowStyle Hidden -Wait:$Verify -PassThru -RedirectStandardOutput (Join-Path $socialLogs ('launch-' + $Stage + '.log')) -RedirectStandardError (Join-Path $socialLogs ('launch-' + $Stage + '-stderr.log'))
if ($Verify) {
    $socialProcess.WaitForExit()
    $socialErrors = Get-Content (Join-Path $socialLogs ('launch-' + $Stage + '-stderr.log')) -Raw
    if ($socialProcess.ExitCode -ne 0 -or $socialErrors -match 'SCRIPT ERROR|Parse Error|FAIL ') { throw "Scenario launch failed (exit $($socialProcess.ExitCode)); see launch logs." }
    if ($Stage -ne 'normal' -and (Get-Content (Join-Path $socialLogs ('launch-' + $Stage + '.log')) -Raw) -notmatch ('SOCIAL V27 PREVIEW: ' + [regex]::Escape($Stage))) { throw 'Requested scenario was not entered.' }
    Write-Output "Verified: $Stage"
} else { Write-Output "Started: $Stage; saves isolated in $env:APPDATA" }
