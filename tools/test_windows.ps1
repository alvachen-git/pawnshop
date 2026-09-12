param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [string]$StartAt = '',
    [switch]$GoodsOnly
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
$script:waitingForStart = -not [string]::IsNullOrEmpty($StartAt)
function Run-Test([string]$Name, [string]$Script, [string[]]$UserArgs = @(), [bool]$Headless = $true) {
    if ($script:waitingForStart) {
        if ($Name -ne $StartAt) { return }
        $script:waitingForStart = $false
    }
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
    Run-Test 'goods-core' 'run_goods_expertise.gd'
    Run-Test 'goods-edges' 'goods_edges.gd'
    Run-Test 'goods-process-write' 'goods_checkpoint.gd'
    Run-Test 'goods-process-read' 'goods_checkpoint.gd' @('read')
    Run-Test 'goods-market' 'run_market_seven.gd' @('goods')
    Run-Test 'goods-early-redemption' 'run_early_redemption.gd' @('goods')
    Run-Test 'goods-ui-fixture' 'goods_ui_fixture.gd'
    foreach ($wide in @($false,$true)) {
        $size = if ($wide) { '1600x900' } else { '1280x720' }
        $sizeArgs = @(if ($wide) { 'wide' })
        Run-Test "goods-$size" 'goods_ui.gd' $sizeArgs $false
        Run-Test "goods-appraisal-$size" 'goods_appraisal_ui.gd' $sizeArgs $false
    }
    Run-Test 'goods-pair-process' 'goods_pair_checkpoint.gd'
    if ($GoodsOnly) {
        Run-Test 'goods-legacy-core' 'run_all.gd'
        Run-Test 'goods-legacy-v20' 'pawn_chance_merge.gd'
        New-Item -ItemType Directory -Force -Path (Join-Path $output 'screenshots') | Out-Null
        Get-ChildItem "$root/.godot/qa" -Filter 'goods*.png' | Copy-Item -Destination (Join-Path $output 'screenshots')
        Write-Utf8 (Join-Path $output 'results.json') (ConvertTo-Json -InputObject @($results.ToArray()) -Depth 10)
        Write-Host "WINDOWS GOODS VALIDATION PASSED: $output"
        return
    }
    Run-Test 'core' 'run_all.gd'
    Run-Test 'night-market-core' 'run_night_market.gd'
    Run-Test 'night-market-process' 'run_night_market.gd' @('process-read')
    Run-Test 'free-cloth' 'free_cloth_tests.gd'
    Run-Test 'mirror-chapter-core' 'run_mirror_chapter.gd'
    Run-Test 'mirror-chapter-process' 'mirror_chapter_checkpoint.gd'
    Run-Test 'market-seven-core' 'run_market_seven.gd'
    Run-Test 'market-seven-process' 'market_seven_checkpoint.gd'
    Run-Test 'familiar-core' 'run_familiar_stories.gd'
    Run-Test 'familiar-process' 'familiar_checkpoint_process.gd'
    Run-Test 'familiar-mirror' 'familiar_mirror_integration.gd'
    Run-Test 'early-core' 'run_early_redemption.gd'
    Run-Test 'early-process' 'early_checkpoint_process.gd'
    Run-Test 'complete-core' 'run_complete_seven.gd'
    Run-Test 'complete-early' 'run_complete_early.gd'
    Run-Test 'complete-process' 'complete_checkpoint_process.gd'
    Run-Test 'complete-familiar' 'run_complete_familiar.gd'
    Run-Test 'complete-familiar-process' 'complete_familiar_checkpoint.gd'
    Run-Test 'complete-economy' 'complete_economy.gd' @('quick')
    Run-Test 'complete-market-process' 'complete_market_checkpoint.gd' @('economy')
    Run-Test 'pawn-chance-core' 'run_pawn_chance.gd'
    Run-Test 'pawn-chance-merge' 'pawn_chance_merge.gd'
    Run-Test 'pawn-chance-process-write' 'pawn_chance_checkpoint.gd'
    Run-Test 'pawn-chance-process-read' 'pawn_chance_checkpoint.gd' @('read')
    Run-Test 'pawn-chance-market' 'run_market_seven.gd' @('chance')
    Run-Test 'early-redemption-v20' 'run_early_redemption.gd' @('chance')
    Run-Test 'early-process-v20' 'early_checkpoint_process.gd' @('chance')
    Run-Test 'market-familiar-core' 'run_market_seven.gd' @('combined')
    Run-Test 'early-redemption-v19' 'run_early_redemption.gd' @('combined')
    Run-Test 'early-process-v19' 'early_checkpoint_process.gd' @('combined')
    Run-Test 'room-core' 'run_room.gd'
    Run-Test 'pawn-core' 'run_pawn.gd'
    Run-Test 'variety-core' 'run_variety.gd'
    Run-Test 'market-core' 'run_market.gd'
    Run-Test 'bargaining-core' 'run_bargaining.gd'
    Run-Test 'bargaining-variety-core' 'bargaining_variety_tests.gd'
    Run-Test 'integrated-variety' 'run_integrated_variety.gd'
    Run-Test 'four-night-core' 'run_four_night.gd'
    Run-Test 'seven-night-core' 'run_seven_night.gd'
    Run-Test 'seven-edges' 'seven_edge_tests.gd'
    Run-Test 'departure-core' 'customer_departure_tests.gd'
    Run-Test 'reception-feedback-core' 'reception_feedback_tests.gd'
    Run-Test 'manual-save-core' 'manual_save_tests.gd'
    Run-Test 'opening-core' 'run_opening.gd'
    Run-Test 'integrated-seven-core' 'run_integrated_seven.gd'
    Run-Test 'preparation-core' 'preparation_tests.gd'
    Run-Test 'bell-core' 'bell_tests.gd'
    foreach ($suite in @('ui_smoke','scene_navigation_ui_smoke','m2_ui_smoke','m3_ui_smoke','m4_ui_smoke','m5_ui_smoke','art03_extension_ui_smoke')) {
        Run-Test $suite "$suite.gd" @() $false
    }
    foreach ($wide in @($false,$true)) {
        $size = if ($wide) { '1600x900' } else { '1280x720' }
        $sizeArgs = @(if ($wide) { 'wide' })
        Run-Test "night-lighting-$size" 'night_lighting_ui.gd' $sizeArgs $false
        Run-Test "incense-smoke-$size" 'incense_smoke_ui.gd' $sizeArgs $false
        Run-Test "night-market-$size" 'night_market_ui.gd' $sizeArgs $false
        Run-Test "complete-early-$size" 'complete_early_ui.gd' $sizeArgs $false
        Run-Test "complete-$size" 'complete_ui_smoke.gd' $sizeArgs $false
        Run-Test "market-seven-$size" 'market_seven_ui_smoke.gd' $sizeArgs $false
        Run-Test "early-$size" 'early_redemption_ui.gd' $sizeArgs $false
        Run-Test "manual-save-$size" 'manual_save_ui_smoke.gd' $sizeArgs $false
        Run-Test "mirror-chapter-$size" 'mirror_chapter_ui_smoke.gd' $sizeArgs $false
        Run-Test "pawn-chance-$size" 'pawn_chance_ui.gd' $sizeArgs $false
        Run-Test "early-redemption-v20-$size" 'early_redemption_ui.gd' (@('chance') + $sizeArgs) $false
        Run-Test "counter-notice-$size" 'counter_notice_ui_smoke.gd' $sizeArgs $false
        Run-Test "early-redemption-v19-$size" 'early_redemption_ui.gd' (@('combined') + $sizeArgs) $false
        Run-Test "bell-$size" 'bell_ui_smoke.gd' $sizeArgs $false
        Run-Test "integrated-seven-$size" 'integrated_ui_smoke.gd' $sizeArgs $false
        Run-Test "preparation-$size" 'preparation_ui_smoke.gd' $sizeArgs $false
        Run-Test "preparation-default-$size" 'preparation_ui_smoke.gd' (@('default') + $sizeArgs) $false
        Run-Test "opening-$size" 'opening_ui_smoke.gd' $sizeArgs $false
        Run-Test "variety-$size" 'variety_ui_smoke.gd' $sizeArgs $false
        Run-Test "market-$size" 'market_ui_smoke.gd' $sizeArgs $false
        Run-Test "seven-$size" 'seven_ui_smoke.gd' (@('--seed=42') + $sizeArgs) $false
        Run-Test "four-$size" 'four_ui_smoke.gd' $sizeArgs $false
        Run-Test "title-menu-$size" 'title_menu_ui_smoke.gd' $sizeArgs $false
        Run-Test "pawn-$size" 'pawn_ui_smoke.gd' $sizeArgs $false
        Run-Test "room-$size" 'room_ui_smoke.gd' $sizeArgs $false
        Run-Test "departure-$size" 'customer_departure_ui_smoke.gd' $sizeArgs $false
        Run-Test "reception-feedback-$size" 'reception_feedback_ui_smoke.gd' $sizeArgs $false
        Run-Test "waiting-departure-$size" 'waiting_departure_ui_smoke.gd' $sizeArgs $false
        Run-Test "receipt-$size" 'receipt_ui_smoke.gd' $sizeArgs $false
        Run-Test "receipt-consistency-$size" 'receipt_consistency_ui.gd' $sizeArgs $false
        Run-Test "trade-feedback-lifecycle-$size" 'trade_feedback_lifecycle_ui.gd' $sizeArgs $false
        Run-Test "customer-reply-$size" 'customer_reply_ui.gd' $sizeArgs $false
        Run-Test "bargaining-$size" 'bargaining_ui_smoke.gd' $sizeArgs $false
        Run-Test "m7-$size" 'm7_ui_smoke.gd' $sizeArgs $false
        Run-Test "m6-production-$size" 'm6_ui_smoke.gd' (@('production') + $sizeArgs) $false
        Run-Test "accounts-$size" 'art03_ui_smoke.gd' $sizeArgs $false
        Run-Test "debt-production-$size" 'art03_debt_ui_smoke.gd' (@('production') + $sizeArgs) $false
    }
    Run-Test 'complete-market-ui-process' 'complete_market_checkpoint.gd' @('ui','economy')
    Run-Test 'market-seven-ui-process' 'market_seven_checkpoint.gd' @('ui')
    foreach ($mode in @('write','read','continue','read_final')) {
        Run-Test "manual-process-$mode" 'manual_save_process.gd' @($mode)
    }
    foreach ($mode in @('opening','first','third','risk','survive','sixth','end','read')) {
        Run-Test "integrated-process-$mode" 'integrated_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('start','attract','tea','finish','second','target','intel','third','sixth','end','read')) {
        Run-Test "preparation-process-$mode" 'preparation_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('prepare','sixth','room','sleep','seventh','finish','read')) {
        Run-Test "seven-process-$mode" 'seven_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('write','next','read')) {
        Run-Test "market-process-$mode" 'market_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('write','fourth','room','sleep','finish','read')) {
        Run-Test "four-process-$mode" 'four_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('write','settle','read')) {
        Run-Test "pawn-process-$mode" 'pawn_checkpoint_process.gd' @($mode)
        Run-Test "variety-process-$mode" 'variety_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('write','resume','read')) {
        Run-Test "m7-process-$mode" 'm7_checkpoint_process.gd' @($mode)
        if ($mode -eq 'write') { Run-Test 'v7-copy-compatibility' 'm8a_save_copy.gd' }
    }
    foreach ($kind in @('scenario','ordinary')) {
        foreach ($step in @('write','sleep','read')) {
            Run-Test "bargaining-process-$step-$kind" 'bargaining_checkpoint_process.gd' @("${step}_${kind}")
        }
    }
    foreach ($mode in @('write_room','sleep','summary','read_summary','write_shop','read_shop','write_pursuit','pursuit_sleep','death','read_death')) {
        Run-Test "room-process-$mode" 'room_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('write_debt','resume_bankrupt','read_bankrupt','write_mirror','resume_death','read_death')) {
        Run-Test "m6-process-$mode" 'm6_checkpoint_process.gd' @($mode)
    }
    foreach ($mode in @('warning','death','restart','archive')) {
        Run-Test "m5-process-$mode" 'm5_checkpoint_process.gd' @($mode)
    }
    if ($script:waitingForStart) { throw "Unknown start test: $StartAt" }
    if ($StartAt) { Write-Utf8 (Join-Path $output 'start-at.txt') $StartAt }
    # Screenshots are produced by the existing real-viewport tests, not by release EXE.
    if (Test-Path "$root/.godot/qa") { Copy-Item "$root/.godot/qa" (Join-Path $output 'screenshots') -Recurse }
    Write-Utf8 (Join-Path $output 'results.json') (ConvertTo-Json -InputObject @($results.ToArray()) -Depth 10)
    Write-Host "WINDOWS SOURCE VALIDATION PASSED: $output (start: $StartAt)"
} finally {
    $env:APPDATA = $oldAppData
    $env:PAWNSHOP_TEST_APPDATA = $oldExpected
}
