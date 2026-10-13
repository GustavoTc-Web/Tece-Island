param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Continue'
$taskNames = @('validate_combat_feedback','validate_base_practical','validate_journal','validate_objectives','validate_account_progress','validate_session_progress','validate_crafting','validate_bags','validate_chest_bow_save','validate_monsters','validate_aquatic_animals','validate_ruins','validate_expansion','validate_wells','validate_base_pieces','validate_controls','validate_auth','validate_auth_release','validate_stage2','validate_update_a','validate_update_b','validate_update_c','validate_v05')
foreach ($taskName in $taskNames) {
    & $Godot --headless --path . --log-file ".tools/signal-suite-$taskName-engine.log" --script "tests/$taskName.gd" *> ".tools/signal-suite-$taskName.log"
    $taskExitCode = $LASTEXITCODE
    Write-Output "$taskName : exit=$taskExitCode"
    Get-Content -LiteralPath ".tools/signal-suite-$taskName.log" -Tail 1
    if ($taskExitCode -ne 0) { exit $taskExitCode }
}
