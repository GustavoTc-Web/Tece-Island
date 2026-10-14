param([string]$Godot = $env:GODOT_EXE, [Parameter(Mandatory=$true)][string]$AllowedUid)
$ErrorActionPreference = "Stop"
if (-not $Godot) { throw "Passe -Godot com o Godot 4.7.2." }
if (-not $AllowedUid.Trim() -or $AllowedUid.Contains(",")) { throw "Informe o UID da sua conta de teste, sem senha ou token." }
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskCopy = Join-Path $taskRoot ".tools/sync-real-project"
$taskOutput = Join-Path $taskRoot "build/sync-test"
$taskPreviousEnabled = $env:TECE_SYNC_ENABLED
$taskPreviousUids = $env:TECE_SYNC_ALLOWED_UIDS
Push-Location $taskRoot
try {
    New-Item -ItemType Directory -Force $taskCopy, $taskOutput | Out-Null
    foreach ($taskName in @("scripts", "scenes", "web", "config", "assets")) {
        Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Recurse -Force
    }
    foreach ($taskName in @("project.godot", "icon.svg", "export_presets.cfg")) {
        Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Force
    }
    $env:TECE_SYNC_ENABLED = "true"
    $env:TECE_SYNC_ALLOWED_UIDS = $AllowedUid.Trim()
    node tools/configure-world-sync.mjs --output (Join-Path $taskCopy "config/world-sync.json")
    if ($LASTEXITCODE -ne 0) { throw "Configuração de piloto inválida." }
    $taskProject = Join-Path $taskCopy "project.godot"
    $taskText = [IO.File]::ReadAllText($taskProject).Replace('config/name="TC Island"', 'config/name="TC Island Sync Test"')
    [IO.File]::WriteAllText($taskProject, $taskText)
    $taskPreset = Join-Path $taskCopy "export_presets.cfg"
    $taskText = [IO.File]::ReadAllText($taskPreset).Replace("res://.tools/godot-templates/", ($taskRoot.Replace("\", "/") + "/.tools/godot-templates/"))
    [IO.File]::WriteAllText($taskPreset, $taskText)
    & $Godot --headless --path $taskCopy --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Falha ao importar o piloto." }
    & $Godot --headless --path $taskCopy --export-release Web (Join-Path $taskOutput "index.html")
    if ($LASTEXITCODE -ne 0) { throw "Falha ao exportar o piloto." }
    New-Item -ItemType Directory -Force (Join-Path $taskOutput "assets/fonts") | Out-Null
    Copy-Item -Path assets/fonts/*.ttf -Destination (Join-Path $taskOutput "assets/fonts") -Force
    Write-Output "Piloto isolado: node tools/serve-web.mjs 8086 build/sync-test"
    Write-Output "Nativo: .tools/sync-real-project/project.godot (F5). Use apenas sua conta de teste."
} finally {
    $env:TECE_SYNC_ENABLED = $taskPreviousEnabled
    $env:TECE_SYNC_ALLOWED_UIDS = $taskPreviousUids
    Pop-Location
}
