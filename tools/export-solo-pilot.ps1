param([string]$Godot = $env:GODOT_EXE, [Parameter(Mandatory=$true)][string]$AllowedUid)
$ErrorActionPreference = 'Stop'
if (-not $Godot) { throw 'Passe -Godot com o caminho do Godot 4.7.2.' }
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskUids = @($AllowedUid.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($taskUids.Count -ne 2) { throw 'Este piloto mantém exatamente as duas contas já autorizadas.' }
$taskCopy = Join-Path $taskRoot '.tools/solo-pilot-project'
$taskOutput = Join-Path $taskRoot 'build/solo-pilot'
New-Item -ItemType Directory -Force $taskCopy,$taskOutput | Out-Null
foreach ($taskName in @('scripts','scenes','web','config','assets','project.godot','icon.svg','export_presets.cfg')) {
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Recurse -Force
}
foreach ($taskName in @('world-sync','global-chat')) {
    $taskConfig = @{ enabled=$true; allowed_uids=$taskUids }
    if ($taskName -eq 'world-sync') { $taskConfig.interval_seconds = 120 }
    [IO.File]::WriteAllText((Join-Path $taskCopy "config/$taskName.json"),($taskConfig | ConvertTo-Json))
}
$taskStamp = @{ version='0.9.0-solo-pilot.1'; commit=(git -C $taskRoot rev-parse HEAD).Trim(); emulated=$false; world_sync=$true; campaign_schema=1; base_release='0.8.3' }
[IO.File]::WriteAllText((Join-Path $taskCopy 'config/build-public.json'),($taskStamp | ConvertTo-Json))
$taskPreset = Join-Path $taskCopy 'export_presets.cfg'
$taskText = [IO.File]::ReadAllText($taskPreset).Replace('res://.tools/godot-templates/',($taskRoot.Replace('\','/')+'/.tools/godot-templates/'))
[IO.File]::WriteAllText($taskPreset,$taskText)
foreach ($taskStage in @('import','export')) {
    $taskLog = Join-Path $taskRoot ".tools/solo-pilot-$taskStage.log"
    $ErrorActionPreference = 'Continue'
    if ($taskStage -eq 'import') { & $Godot --headless --path $taskCopy --editor --import --quit *> $taskLog }
    else { & $Godot --headless --path $taskCopy --export-release Web (Join-Path $taskOutput 'index.html') *> $taskLog }
    $taskExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($taskExit -ne 0 -or (Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR|Parse Error|Export failed' -Quiet)) {
        Get-Content $taskLog -Tail 60
        throw "Falha no piloto: $taskStage"
    }
}
New-Item -ItemType Directory -Force (Join-Path $taskOutput 'assets/fonts') | Out-Null
Copy-Item -Path (Join-Path $taskRoot 'assets/fonts/*.ttf'),(Join-Path $taskRoot 'assets/fonts/*OFL.txt') -Destination (Join-Path $taskOutput 'assets/fonts') -Force
Copy-Item -LiteralPath (Join-Path $taskCopy 'config/build-public.json') -Destination (Join-Path $taskOutput 'version.json') -Force
Write-Output "Piloto privado exportado: $taskOutput"
