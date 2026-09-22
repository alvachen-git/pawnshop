# Optional downloader for slow official large-file transfers. Requires PowerShell 7.
# No system proxy/PATH changes; all chunks and downloads stay under ignored .tools.
# The build command independently verifies the complete archive again.
#requires -Version 7.0
param([string]$Proxy = '', [string]$ResumePartsDirectory = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$downloadDir = Join-Path $root '.tools/downloads'
$parts = if ($ResumePartsDirectory) { [IO.Path]::GetFullPath($ResumePartsDirectory) } else { Join-Path $downloadDir ('parts-' + [Guid]::NewGuid().ToString('N')) }
if (-not $parts.StartsWith([IO.Path]::GetFullPath($downloadDir) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Parts directory must be inside this project download cache.' }
New-Item -ItemType Directory -Force -Path $parts | Out-Null
$size = 1249771228L
$chunkSize = 32MB
$count = [int][Math]::Ceiling($size / $chunkSize)
$proxyArg = $Proxy
$baseUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz'
0..($count-1) | ForEach-Object -ThrottleLimit 8 -Parallel {
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $false
    $index = $_
    $start = [long]$index * $using:chunkSize
    $end = [Math]::Min($start + $using:chunkSize - 1, $using:size - 1)
    $dest = Join-Path $using:parts ('{0:D3}.part' -f $index)
    $have = if (Test-Path $dest) { (Get-Item $dest).Length } else { 0L }
    if ($have -gt $end-$start+1) { throw "Oversized downloaded part $index" }
    while ($start + $have -le $end) {
        $from = $start + $have
        $to = [Math]::Min($from + 4MB - 1, $end)
        $segment = $dest + '.segment'
        $ok = $false
        for ($attempt=0; $attempt -lt 4; $attempt++) {
            $curlArgs = @('-sS','--fail','--location','--connect-timeout','20','--max-time','120', '--range',"$from-$to",'--output',$segment)
            if ($using:proxyArg) { $curlArgs += @('--proxy',$using:proxyArg) }
            $url = $using:baseUrl + '?m8a-part=' + $index + '-' + [Guid]::NewGuid().ToString('N')
            & curl.exe @curlArgs $url 2> ($dest + '.curl.log')
            if ($LASTEXITCODE -eq 0 -and (Get-Item $segment).Length -eq $to-$from+1) { $ok=$true; break }
        }
        if (-not $ok) { throw "Unable to complete range $from-$to; rerun with -ResumePartsDirectory $using:parts" }
        $source = [IO.File]::OpenRead($segment)
        $destination = [IO.File]::Open($dest,[IO.FileMode]::Append)
        try { $source.CopyTo($destination) } finally { $source.Dispose(); $destination.Dispose() }
        $have = (Get-Item $dest).Length
    }
    Write-Host "Verified length: part $index"
}
$target = Join-Path $downloadDir 'Godot_v4.6.1-stable_export_templates.tpz'
$temporary = Join-Path $parts 'assembled.tpz'
$output = [IO.File]::Create($temporary)
try {
    for ($i=0; $i -lt $count; $i++) {
        $path = Join-Path $parts ('{0:D3}.part' -f $i)
        $expectedLength = [Math]::Min($chunkSize, $size - [long]$i * $chunkSize)
        if ((Get-Item $path).Length -ne $expectedLength) { throw "Missing/invalid part $i" }
        $inputFile = [IO.File]::OpenRead($path)
        try { $inputFile.CopyTo($output) } finally { $inputFile.Dispose() }
    }
} finally { $output.Dispose() }
$expected = 'd80001711c07973b1fd3e88077ba99644e19db7c9e52627e16f38a2937879f809f94dbd8493936fb8204908bbc57a521d41173dce5208061fe4c99772490c541'
if ((Get-FileHash $temporary -Algorithm SHA512).Hash -ne $expected) { throw 'Official SHA512 mismatch; assembled download not published.' }
Copy-Item -LiteralPath $temporary -Destination $target -Force
Write-Host "Official template SHA512 verified: $target"
