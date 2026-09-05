param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string]$TemplatesArchive = '',
    [string]$EditorArchive = ''
)
. "$PSScriptRoot/windows_common.ps1"
$root = Split-Path $PSScriptRoot -Parent
$engine = Get-CheckedGodot $GodotPath
if (-not $TemplatesArchive) { $TemplatesArchive = "$root/.tools/downloads/Godot_v4.6.1-stable_export_templates.tpz" }
if (-not $EditorArchive) { $EditorArchive = "$root/.tools/downloads/Godot_v4.6.1-stable_win64.exe.zip" }
$templateHash = 'd80001711c07973b1fd3e88077ba99644e19db7c9e52627e16f38a2937879f809f94dbd8493936fb8204908bbc57a521d41173dce5208061fe4c99772490c541'
$editorHash = '67c63291115c66ebe7145415b5aac235e1667e417d6cd3d1975848670a1d31cbfad111c8231cb53195bb62e6e4fde951d97aaca227736a94f93dcbf8f23b1fbb'
foreach ($pair in @(@($TemplatesArchive,$templateHash), @($EditorArchive,$editorHash))) {
    if ((Get-FileHash -LiteralPath $pair[0] -Algorithm SHA512).Hash -ne $pair[1]) { throw "Official SHA512 mismatch: $($pair[0])" }
}
if ((Get-FileHash "$root/assets/fonts/NotoSansSC.ttf").Hash -ne 'A3041811A78C361B1DE50F953C805E0244951C21C5BD412F7232EF0D899AF0DA') { throw 'Font differs from pinned original.' }
if ((Get-FileHash "$root/assets/fonts/OFL.txt").Hash -ne '1C05C68C34F9708415AADA51F17E1B0092D2CEA709BF4A94CD38114F9E73D7D9') { throw 'Font license differs from original.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
# Verify the chosen executable (and console sibling) against the official editor ZIP.
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $EditorArchive).Path)
try {
    foreach ($name in @('Godot_v4.6.1-stable_win64.exe','Godot_v4.6.1-stable_win64_console.exe')) {
        $entry = $archive.GetEntry($name)
        if ($null -eq $entry) { throw "Missing official editor entry $name" }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $expected = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') } finally { $stream.Dispose(); $sha.Dispose() }
        if ((Get-FileHash (Join-Path (Split-Path $engine) $name)).Hash -ne $expected) { throw "Editor executable differs: $name" }
    }
} finally { $archive.Dispose() }
$buildId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
$work = Join-Path $root ".artifacts/m8a/$buildId"
$stage = Join-Path $work 'project'
$package = Join-Path $work 'package'
$templates = Join-Path $work 'templates'
New-Item -ItemType Directory -Force -Path $stage,$package,$templates | Out-Null
Write-Host "BUILD $buildId"
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $TemplatesArchive).Path)
try {
    foreach ($name in @('windows_release_x86_64.exe','windows_debug_x86_64.exe','version.txt')) {
        $entry = @($archive.Entries | Where-Object { $_.Name -eq $name })
        if ($entry.Count -ne 1) { throw "Missing/ambiguous template: $name" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0], (Join-Path $templates $name))
    }
} finally { $archive.Dispose() }
if (([IO.File]::ReadAllText("$templates/version.txt")).Trim() -ne '4.6.1.stable') { throw 'Wrong template version.' }

$gitArgs = @('-c', "safe.directory=$($root.Replace('\','/'))", '-C', $root)
$commit = (& git @gitArgs rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot record source commit.' }
$gitStatus = @(& git @gitArgs status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Cannot record workspace status.' }

# Reject production edits made while the test gate is running.
function Get-ProductionFingerprint {
    $snapshot = [ordered]@{}
    foreach ($folder in @('core','ui','scenes','data','assets')) {
        Get-ChildItem "$root/$folder" -Recurse -File | Where-Object { $_.Name -match '\.(gd|tscn|json|svg|ttf)$' -or $_.Name -eq 'NotoSansSC.ttf.import' } | Sort-Object FullName | ForEach-Object { $snapshot[$_.FullName.Substring($root.Length+1)] = (Get-FileHash -LiteralPath $_.FullName).Hash }
    }
    foreach ($file in @('project.godot','export_presets.cfg')) { $snapshot[$file] = (Get-FileHash "$root/$file").Hash }
    return ($snapshot | ConvertTo-Json -Compress)
}
$testedFingerprint = Get-ProductionFingerprint
# Run the full source gate, with independent user data. No SkipTests switch.
& "$PSScriptRoot/test_build_gates.ps1" -OutputDir "$work/build-gates"
& "$PSScriptRoot/test_windows.ps1" -GodotPath $engine -OutputDir "$work/validation"
if ((Get-ProductionFingerprint) -ne $testedFingerprint) { throw 'Production files changed during validation; rebuild against a stable snapshot.' }

$manifest = Get-Content -LiteralPath "$root/data/content_manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.content_version -ne 9 -or $manifest.default_run_id -ne 'p0_room') { throw 'V06-Pawn.1 requires content_version=9 and p0_room.' }
$jsonFiles = @('res://data/content_manifest.json') + @($manifest.sources | ForEach-Object { $_.path })
if (@($jsonFiles | Sort-Object -Unique).Count -ne $jsonFiles.Count) { throw 'Duplicate manifest source path.' }
$files = [Collections.Generic.List[string]]::new()
foreach ($folder in @('core','ui')) {
    Get-ChildItem "$root/$folder" -Recurse -File | Where-Object { $_.Name -match '\.gd(\.uid)?$' } | ForEach-Object { $files.Add($_.FullName.Substring($root.Length+1).Replace('\','/')) }
}
foreach ($file in @('project.godot','export_presets.cfg','scenes/main.gd','scenes/main.gd.uid','scenes/main.tscn','assets/fonts/NotoSansSC.ttf','assets/fonts/NotoSansSC.ttf.import')) { $files.Add($file) }
$visuals = @(Get-ChildItem "$root/assets/art02" -Recurse -File -Filter '*.svg' | ForEach-Object { $_.FullName.Substring($root.Length+1).Replace('\','/') })
foreach ($file in $visuals) { $files.Add($file); if (Test-Path "$root/$file.import") { $files.Add("$file.import") } }
foreach ($path in $jsonFiles) {
    if ($path -notmatch '^res://data/[a-zA-Z0-9_/.-]+\.json$' -or $path.Contains('..')) { throw "Unsafe content path: $path" }
    $files.Add($path.Substring(6))
}
$sourceHashes = [ordered]@{}
foreach ($file in $files) {
    $target = Join-Path $stage $file
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath "$root/$file" -Destination $target
    $sourceHashes[$file] = (Get-FileHash -LiteralPath $target).Hash
}
# Source strings only for glyph auditing; never copied to player build metadata.
$characters = [Collections.Generic.HashSet[char]]::new()
foreach ($file in @($files | Where-Object { $_ -match '\.(gd|tscn|json)$' })) {
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText("$root/$file"), '[\u4e00-\u9fff\u3000-\u303f\uff01-\uff60\u2010-\u2027\u00b7]')) { [void]$characters.Add($match.Value[0]) }
}
$jsonHashes = [ordered]@{}
foreach ($path in $jsonFiles) { $jsonHashes[$path] = $sourceHashes[$path.Substring(6)] }
$spec = @{ json_files=$jsonFiles; json_sha256=$jsonHashes; visual_files=@($visuals | ForEach-Object { "res://$_" }); font_characters=(-join @($characters | Sort-Object)) }
Write-Utf8 "$work/pack-spec.json" ($spec | ConvertTo-Json -Depth 10)
Write-Utf8 "$work/source-sha256.json" ($sourceHashes | ConvertTo-Json -Depth 10)
# Generate the staging filter from the manifest, not a manually maintained second content list.
$preset = [IO.File]::ReadAllText("$stage/export_presets.cfg")
$filter = (@($jsonFiles | ForEach-Object { $_.Substring(6) }) + $visuals + @('assets/fonts/NotoSansSC.ttf')) -join ','
$preset = [regex]::Replace($preset, '(?m)^include_filter=.*$', ('include_filter="' + $filter + '"'))
$preset = $preset.Replace('custom_template/release=""', 'custom_template/release="' + "$templates/windows_release_x86_64.exe".Replace('\','/') + '"')
$preset = $preset.Replace('custom_template/debug=""', 'custom_template/debug="' + "$templates/windows_debug_x86_64.exe".Replace('\','/') + '"')
Write-Utf8 "$stage/export_presets.cfg" $preset
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = "$work/export-appdata"
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    Invoke-GodotChecked $engine @('--headless','--editor','--path',$stage,'--quit') "$work/staging-import.log" | Out-Null
    Invoke-GodotChecked $engine @('--headless','--path',$stage,'--export-release','Windows M8A',"$package/Pawnshop.exe") "$work/export.log" | Out-Null
    foreach ($file in @('Pawnshop.exe','Pawnshop.pck')) { if (-not (Test-Path "$package/$file") -or (Get-Item "$package/$file").Length -eq 0) { throw "Missing export $file" } }
    $auditDir = "$work/empty-audit-project"
    New-Item -ItemType Directory -Path $auditDir | Out-Null
    Write-Utf8 "$auditDir/project.godot" 'config_version=5'
    Invoke-GodotChecked $engine @('--headless','--path',$auditDir,'--script',"$PSScriptRoot/audit_pack.gd",'--',"$package/Pawnshop.pck","$work/pack-spec.json","$work/pack-audit.json") "$work/pack-audit.log" 'M8A PACK AUDIT:.*0 failures' | Out-Null
} finally { $env:APPDATA = $oldAppData }

New-Item -ItemType Directory -Path "$package/licenses" | Out-Null
Copy-Item "$root/assets/fonts/OFL.txt" "$package/licenses/NotoSansSC-OFL.txt"
Copy-Item "$root/assets/fonts/SOURCE.md" "$package/licenses/NotoSansSC-source.md"
Copy-Item "$root/third_party/godot/LICENSE.txt" "$package/licenses/Godot-LICENSE.txt"
Copy-Item "$root/third_party/godot/COPYRIGHT.txt" "$package/licenses/Godot-COPYRIGHT.txt"
Copy-Item "$root/third_party/godot/SOURCE.md" "$package/licenses/Godot-source.md"
Copy-Item "$PSScriptRoot/PLAYTEST_WINDOWS.txt" "$package/PLAYTEST_WINDOWS.txt"
$info = [ordered]@{
    version='V06-Pawn.1'; engine='4.6.1.stable.official.14d19694e'; target='Windows x86_64'; renderer='gl_compatibility';
    build_id=$buildId; built_at_utc=[DateTime]::UtcNow.ToString('o'); source_commit=$commit; workspace_dirty=($gitStatus.Count -gt 0); workspace_status=$gitStatus;
    content_version=9; save_version=9; run_definition_id=$manifest.default_run_id;
    save_relative_path='user://p0/autosave_v9.json'; user_directory='%APPDATA%/GhostMarketPawnshop-M8A'; signed=$false;
    source_files_sha256=$sourceHashes; json_files=$jsonFiles;
    editor_zip_sha512=$editorHash; templates_tpz_sha512=$templateHash;
    editor_source='https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_win64.exe.zip';
    templates_source='https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz';
    checksums_source='https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/SHA512-SUMS.txt';
    exe_sha256=(Get-FileHash "$package/Pawnshop.exe").Hash; pck_sha256=(Get-FileHash "$package/Pawnshop.pck").Hash;
    source_tests='passed; results retained in local build validation directory'; pack_audit='passed';
    actual_exe_gameplay_acceptance='PENDING MANUAL ACCEPTANCE'; untested_platforms=@('Windows 10','Windows ARM64','Windows 7/8','other PCs and DPI configurations')
}
Write-Utf8 "$package/BUILD_INFO.json" ($info | ConvertTo-Json -Depth 10)
# A unique output directory preserves previous successful packages and all failed build evidence.
$candidate = Join-Path $work 'Pawnshop-V06-Pawn.1-windows-x86_64.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($package, $candidate, [IO.Compression.CompressionLevel]::Optimal, $false)
if ((Get-ProductionFingerprint) -ne $testedFingerprint) { throw 'Production files changed during packaging; this candidate is not approved.' }
$destination = Join-Path $root "dist/$buildId"
New-Item -ItemType Directory -Path $destination | Out-Null
$zip = Join-Path $destination 'Pawnshop-V06-Pawn.1-windows-x86_64.zip'
Copy-Item -LiteralPath $candidate -Destination $zip
Write-Utf8 ($zip + '.sha256') ((Get-FileHash $zip).Hash.ToLower() + '  ' + [IO.Path]::GetFileName($zip) + "`n")
Copy-Item "$work/pack-audit.json" "$destination/pack-audit.json"
Copy-Item "$work/validation/results.json" "$destination/source-test-results.json"
Write-Host "LOCAL PACKAGE READY (manual EXE acceptance still pending): $zip"
