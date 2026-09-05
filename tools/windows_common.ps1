Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Invoke-GodotChecked {
    param([string]$Executable, [string[]]$Arguments, [string]$LogPath,
          [string]$SuccessPattern = '', [int]$TimeoutSeconds = 300)
    # Only task-owned children are stopped on timeout. Never kill all Godot processes.
    $quoted = @($Arguments | ForEach-Object {
        if ($_ -match '"') { throw 'Arguments containing double quotes are unsupported.' }
        '"' + $_ + '"'
    })
    $stderrPath = $LogPath + '.stderr'
    $process = Start-Process -FilePath $Executable -ArgumentList $quoted -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $LogPath -RedirectStandardError $stderrPath
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        throw "Timed out: $LogPath"
    }
    $process.WaitForExit()
    $log = [IO.File]::ReadAllText($LogPath) + [IO.File]::ReadAllText($stderrPath)
    Write-Utf8 $LogPath $log
    # Assertion markers are uppercase. A warning saying "will fail if disk is full"
    # is retained as a warning, not mistaken for an already failed assertion.
    if ($process.ExitCode -ne 0 -or $log -match '(?im)SCRIPT ERROR|Parse Error|Invalid call|ERROR:|(?-i:\bFAIL(?:ED)?\b)|[1-9][0-9]* failures') {
        throw "Godot failed (exit $($process.ExitCode)); inspect $LogPath"
    }
    if ($SuccessPattern -and $log -notmatch $SuccessPattern) { throw "Missing success marker: $LogPath" }
    Write-Host "PASS $([IO.Path]::GetFileName($LogPath))"
    return $log
}

function Get-CheckedGodot([string]$Path) {
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $version = (& $resolved --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -ne '4.6.1.stable.official.14d19694e') {
        throw "Expected official Godot 4.6.1 Standard, got: $version"
    }
    return $resolved
}
