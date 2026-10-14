param([string]$Godot = $env:GODOT_EXE)
$ErrorActionPreference = "Stop"
if (-not $Godot) { throw "Passe -Godot com o caminho do Godot 4.7.2." }
$taskRoot = Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
try {
    New-Item -ItemType Directory -Force .tools | Out-Null
    foreach ($taskTest in @("validate_world_library", "validate_account_progress", "validate_session_progress", "validate_save_reliability", "validate_world_sync", "validate_chest_bow_save", "validate_auth_release")) {
        $taskOutput = Join-Path $taskRoot ".tools/save-suite-$taskTest.log"
        $ErrorActionPreference = "Continue"
        & $Godot --headless --path . --script "tests/$taskTest.gd" --log-file ".tools/save-suite-$taskTest-engine.log" *> $taskOutput
        $taskTestExit = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        if ($taskTestExit -ne 0 -or (Select-String -LiteralPath $taskOutput -Pattern "SCRIPT ERROR|FAIL:" -Quiet)) {
            Get-Content -LiteralPath $taskOutput
            throw "Falha em $taskTest"
        }
        Get-Content -LiteralPath $taskOutput | Select-Object -Last 2
    }
} finally { Pop-Location }
