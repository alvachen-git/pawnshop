$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $PSScriptRoot
$qaRoot = Join-Path $gameRoot '.godot/qa/special-guests/launcher-probe'
New-Item -ItemType Directory -Path $qaRoot -Force | Out-Null
$probeExe = Join-Path $qaRoot ('engine-' + [guid]::NewGuid().ToString('N') + '.exe')
$source = @"
using System;
public class LauncherProbe {
    public static int Main(string[] args) {
        string mode = Environment.GetEnvironmentVariable("SPECIAL_GUESTS_LAUNCH_PROBE");
        if (Array.IndexOf(args, "--headless") >= 0) {
            Console.Error.WriteLine(mode == "script" ? "SCRIPT ERROR: simulated parser failure" : "WARNING: Missing .uid file; recreated from cache.");
            return mode == "exit" ? 7 : 0;
        }
        Console.WriteLine("LAUNCH_REACHED:" + mode);
        return 0;
    }
}
"@
Add-Type -TypeDefinition $source -OutputAssembly $probeExe -OutputType ConsoleApplication
$previousProbe = $env:SPECIAL_GUESTS_LAUNCH_PROBE
try {
    foreach ($mode in @('warning','exit','script')) {
        $env:SPECIAL_GUESTS_LAUNCH_PROBE = $mode
        $outputLog = Join-Path $qaRoot ($mode + '.log')
        $ErrorActionPreference = 'Continue'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $gameRoot 'tools/play_special_guests.ps1') -GodotPath $probeExe -Stage hat -Verify *> $outputLog
        $result = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $launchLog = Get-Content -LiteralPath (Join-Path $gameRoot '.godot/qa/special-guests/launch-hat.log') -Raw
        if ($mode -eq 'warning') {
            if ($result -ne 0 -or $launchLog -notmatch 'LAUNCH_REACHED:warning') { throw 'Recoverable warning blocked launch.' }
        } else {
            if ($result -eq 0 -or $launchLog -match ('LAUNCH_REACHED:' + $mode)) { throw 'Genuine engine failure did not block launch.' }
        }
        Write-Output "PASS $mode"
    }
} finally { $env:SPECIAL_GUESTS_LAUNCH_PROBE = $previousProbe }
Write-Output 'Launcher regression: 3 passes, 0 failures'
