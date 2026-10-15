param([string]$Godot = $env:GODOT_EXE, [Parameter(Mandatory=$true)][string]$AllowedUid, [switch]$Emulated)
$ErrorActionPreference = "Stop"
if (-not $Godot) { throw "Passe -Godot com o Godot 4.7.2." }
$taskUids = @($AllowedUid.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($taskUids.Count -eq 0) { throw "Informe apenas os UIDs das contas de teste." }
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskLabel = if ($Emulated) { "chat-emulated" } else { "chat-pilot" }
$taskCopy = Join-Path $taskRoot ".tools/$taskLabel-project"
$taskOutput = Join-Path $taskRoot "build/$taskLabel"
New-Item -ItemType Directory -Force $taskCopy,$taskOutput | Out-Null
foreach ($taskName in @("scripts","scenes","web","config","assets")) {
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Recurse -Force
}
foreach ($taskName in @("project.godot","icon.svg","export_presets.cfg")) {
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Force
}
$taskConfig = @{ enabled = $true; allowed_uids = $taskUids } | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $taskCopy "config/global-chat.json"),$taskConfig)
# Keep save sync disabled in the chat pilot; its separate manual validation is pending.
[IO.File]::WriteAllText((Join-Path $taskCopy "config/world-sync.json"),'{"enabled":false,"allowed_uids":[],"interval_seconds":120}')
$taskProject = Join-Path $taskCopy "project.godot"
$taskText = [IO.File]::ReadAllText($taskProject).Replace('config/name="TC Island"','config/name="TC Island Chat Pilot"')
if ($Emulated) {
    New-Item -ItemType Directory -Force (Join-Path $taskCopy "tests") | Out-Null
    Copy-Item -Path (Join-Path $taskRoot "tests/chat_browser_fixture.*") -Destination (Join-Path $taskCopy "tests") -Force
    $taskText = $taskText.Replace('res://scenes/main.tscn','res://tests/chat_browser_fixture.tscn')
    $taskFirebase = Get-Content (Join-Path $taskCopy "config/firebase-public.json") -Raw | ConvertFrom-Json
    $taskFirebase.projectId = "demo-tece-island"
    [IO.File]::WriteAllText((Join-Path $taskCopy "config/firebase-public.json"),($taskFirebase | ConvertTo-Json))
}
[IO.File]::WriteAllText($taskProject,$taskText)
$taskCommit = (git -C $taskRoot rev-parse HEAD).Trim()
$taskDirty = [bool](git -C $taskRoot status --porcelain)
$taskStamp = @{ version="0.8.2-chat-pilot.1"; commit=$taskCommit; working_tree=$taskDirty; emulated=[bool]$Emulated } | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $taskCopy "config/build-public.json"),$taskStamp)
$taskPreset = Join-Path $taskCopy "export_presets.cfg"
$taskText = [IO.File]::ReadAllText($taskPreset).Replace("res://.tools/godot-templates/",($taskRoot.Replace("\","/")+"/.tools/godot-templates/"))
if ($Emulated) { $taskText = $taskText.Replace('tests/*,','') }
[IO.File]::WriteAllText($taskPreset,$taskText)
foreach ($taskStage in @("import","export")) {
    $taskLog = Join-Path $taskRoot ".tools/$taskLabel-$taskStage.log"
    $ErrorActionPreference = "Continue"
    if ($taskStage -eq "import") { & $Godot --headless --path $taskCopy --editor --import --quit *> $taskLog }
    else { & $Godot --headless --path $taskCopy --export-release Web (Join-Path $taskOutput "index.html") *> $taskLog }
    $taskExit = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($taskExit -ne 0 -or (Select-String -LiteralPath $taskLog -Pattern "SCRIPT ERROR|Parse Error" -Quiet)) {
        Get-Content $taskLog -Tail 70
        throw "Falha no piloto: $taskStage"
    }
}
New-Item -ItemType Directory -Force (Join-Path $taskOutput "assets/fonts") | Out-Null
Copy-Item -Path (Join-Path $taskRoot "assets/fonts/*.ttf"),(Join-Path $taskRoot "assets/fonts/*OFL.txt") -Destination (Join-Path $taskOutput "assets/fonts") -Force
Write-Output "Exportado: $taskOutput. Configuração do backend ainda deve ser conferida antes do teste real."
