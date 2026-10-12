param([string]$Godot = $env:GODOT_EXE, [switch]$AuthPreview)
$ErrorActionPreference = "Stop"
if (-not $Godot) { throw "Passe -Godot com o caminho do Godot 4.7.2." }
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskCopy = Join-Path $taskRoot $(if ($AuthPreview) { ".tools/auth-fixture" } else { ".tools/browser-fixture" })
$taskCache = [IO.Path]::GetFullPath((Join-Path $taskCopy ".godot"))
if (-not $taskCache.StartsWith([IO.Path]::GetFullPath((Join-Path $taskRoot ".tools")) + [IO.Path]::DirectorySeparatorChar)) { throw "Cache fora da pasta de testes." }
if (Test-Path -LiteralPath $taskCache) { Remove-Item -LiteralPath $taskCache -Recurse -Force }
New-Item -ItemType Directory -Force $taskCopy | Out-Null
foreach ($taskName in @("scripts", "scenes", "web", "config")) {
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Recurse -Force
}
foreach ($taskName in @("project.godot", "icon.svg", "export_presets.cfg")) {
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Force
}
New-Item -ItemType Directory -Force (Join-Path $taskCopy "tests") | Out-Null
Copy-Item -Path (Join-Path $taskRoot "tests/browser_fixture.*") -Destination (Join-Path $taskCopy "tests") -Force
if ($AuthPreview) { Copy-Item -Path (Join-Path $taskRoot "tests/auth_ui_fixture.*") -Destination (Join-Path $taskCopy "tests") -Force }
$taskProject = Join-Path $taskCopy "project.godot"
$taskScene = if ($AuthPreview) { "res://tests/auth_ui_fixture.tscn" } else { "res://tests/browser_fixture.tscn" }
$taskText = [IO.File]::ReadAllText($taskProject).Replace("res://scenes/main.tscn", $taskScene)
[IO.File]::WriteAllText($taskProject, $taskText)
$taskPreset = Join-Path $taskCopy "export_presets.cfg"
$taskText = [IO.File]::ReadAllText($taskPreset).Replace('tests/*,', '').Replace("res://.tools/godot-templates/", ($taskRoot.Replace("\","/") + "/.tools/godot-templates/"))
[IO.File]::WriteAllText($taskPreset, $taskText)
$taskOutput = Join-Path $taskRoot $(if ($AuthPreview) { ".tools/auth-web-validation" } else { ".tools/web-validation" })
New-Item -ItemType Directory -Force $taskOutput | Out-Null
& $Godot --headless --path $taskCopy --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Importação da fixture falhou." }
& $Godot --headless --path $taskCopy --export-debug Web (Join-Path $taskOutput "index.html")
if ($LASTEXITCODE -ne 0) { throw "Exportação da fixture falhou." }
