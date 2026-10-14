param([string]$Godot = $env:GODOT_EXE)
$ErrorActionPreference = "Stop"
if (-not $Godot) { throw "Passe -Godot com o caminho do Godot 4.7.2." }
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskCopy = Join-Path $taskRoot ".tools/auth-real-project"
$taskOutput = Join-Path $taskRoot "build/auth-test"
$taskPrevious = $env:FIREBASE_AUTH_ENABLED
Push-Location $taskRoot
try {
    New-Item -ItemType Directory -Force $taskCopy, $taskOutput, (Join-Path $taskCopy "config") | Out-Null
    $env:FIREBASE_AUTH_ENABLED = "true"
    node tools/configure-firebase.mjs --output (Join-Path $taskCopy "config/firebase-public.json")
    if ($LASTEXITCODE -ne 0) { throw "Complete a configuração pública do Firebase antes de gerar o teste real." }
    Copy-Item -LiteralPath (Join-Path $taskRoot "config/world-sync.json") -Destination (Join-Path $taskCopy "config/world-sync.json") -Force
    foreach ($taskName in @("scripts", "scenes", "web", "assets")) {
        Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Recurse -Force
    }
    foreach ($taskName in @("project.godot", "icon.svg", "export_presets.cfg")) {
        Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Force
    }
    if (-not (Test-Path ".tools/godot-templates/4.7.2/web_nothreads_release.zip")) {
        node tools/fetch-web-templates.mjs 4.7.2
        if ($LASTEXITCODE -ne 0) { throw "Falha ao obter templates oficiais." }
    }
    $taskPreset = Join-Path $taskCopy "export_presets.cfg"
    $taskText = [IO.File]::ReadAllText($taskPreset).Replace("res://.tools/godot-templates/", ($taskRoot.Replace("\", "/") + "/.tools/godot-templates/"))
    [IO.File]::WriteAllText($taskPreset, $taskText)
    & $Godot --headless --path $taskCopy --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Falha ao importar o projeto de teste." }
    & $Godot --headless --path $taskCopy --export-release Web (Join-Path $taskOutput "index.html")
    if ($LASTEXITCODE -ne 0) { throw "Falha na exportação do teste." }
    Write-Output "Teste real: node tools/serve-web.mjs 8083 build/auth-test"
    Write-Output "Abra http://localhost:8083/Tece-Island/"
    Write-Output "Para PC nativo, importe .tools/auth-real-project/project.godot no Godot e execute F5."
    Write-Output "A configuração de produção permanece inalterada."
} finally {
    $env:FIREBASE_AUTH_ENABLED = $taskPrevious
    Pop-Location
}
