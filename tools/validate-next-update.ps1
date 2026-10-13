param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Continue'
$taskNames = @('validate_next_mechanics','validate_world_library','validate_objectives','validate_combat_feedback','validate_base_practical','validate_journal','validate_account_progress','validate_session_progress','validate_crafting','validate_bags','validate_chest_bow_save','validate_monsters','validate_aquatic_animals','validate_ruins','validate_expansion','validate_wells','validate_base_pieces','validate_controls','validate_auth','validate_auth_release','validate_stage2','validate_update_a','validate_update_b','validate_update_c','validate_v05','validate_menu','validate_mobile')
$taskResults = @()
$taskNames += 'validate_network_history'
foreach ($taskName in $taskNames) {
    & $Godot --headless --path . --log-file ".tools/next-$taskName-engine.log" --script "tests/$taskName.gd" *> ".tools/next-$taskName.log"
    $taskCode = $LASTEXITCODE
    $taskLines = Get-Content -LiteralPath ".tools/next-$taskName.log"
    $taskFailures = @($taskLines | Select-String -Pattern 'FAIL:|SCRIPT ERROR|Parse Error')
    $taskSummary = $taskLines | Select-Object -Last 1
    Write-Output "$taskName : exit=$taskCode : $taskSummary"
    $taskResults += @{name=$taskName;exit=$taskCode;checks=@($taskLines | Select-String -Pattern '^PASS:').Count;failures=$taskFailures.Count}
    if ($taskCode -ne 0 -or $taskFailures.Count -gt 0) {
        $taskFailures | ForEach-Object { Write-Output $_.Line }
        $taskResults | ConvertTo-Json | Set-Content -LiteralPath '.tools/next-native-results.json' -Encoding UTF8
        exit 1
    }
}
$taskResults | ConvertTo-Json | Set-Content -LiteralPath '.tools/next-native-results.json' -Encoding UTF8
