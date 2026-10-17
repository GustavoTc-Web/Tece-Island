param([string]$Godot = $env:GODOT_EXE)
$ErrorActionPreference = "Stop"
if (-not $Godot) { throw "Defina GODOT_EXE ou passe -Godot com o caminho do Godot 4.7.2." }
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    node tools/configure-firebase.mjs
    if ($LASTEXITCODE -ne 0) { throw "Configuração pública do Firebase inválida." }
    if ($env:TECE_PILOT_ALLOWED_UIDS) { node tools/configure-release-access.mjs }
    else { node tools/configure-world-sync.mjs }
    if ($LASTEXITCODE -ne 0) { throw "Configuração de sincronização inválida." }
    node tools/stamp-build.mjs
    if ($LASTEXITCODE -ne 0) { throw "Identificação da versão inválida." }
    if (-not (Test-Path ".tools/godot-templates/4.7.2/web_nothreads_release.zip")) {
        node tools/fetch-web-templates.mjs 4.7.2
        if ($LASTEXITCODE -ne 0) { throw "Falha ao baixar os templates oficiais." }
    }
    New-Item -ItemType Directory -Force build/web | Out-Null
    New-Item -ItemType File -Force build/.gdignore | Out-Null
    & $Godot --headless --path . --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Falha ao importar o projeto." }
    & $Godot --headless --path . --export-release Web build/web/index.html
    if ($LASTEXITCODE -ne 0) { throw "Falha na exportação Web." }
    New-Item -ItemType Directory -Force build/web/assets/fonts | Out-Null
    Copy-Item -Path assets/fonts/*.ttf,assets/fonts/*OFL.txt,assets/fonts/README.md -Destination build/web/assets/fonts -Force
    if ($env:TECE_PILOT_ALLOWED_UIDS) {
        node tools/write-web-manifest.mjs
        if ($LASTEXITCODE -ne 0) { throw "Manifesto da publicação inválido." }
    }
} finally { Pop-Location }
