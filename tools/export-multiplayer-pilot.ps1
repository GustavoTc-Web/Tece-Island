param(
    [string]$Godot = $env:GODOT_EXE,
    [Parameter(Mandatory=$true)][string]$ServerUrl,
    [string]$AllowedUid,
    [string]$AllowedUidsFile,
    [string]$Templates = $env:GODOT_WEB_TEMPLATES,
    [switch]$Fixture
)
$ErrorActionPreference = 'Stop'
if (-not $Godot) { throw 'Passe -Godot com o caminho do Godot 4.7.2.' }
if ($ServerUrl -notmatch '^wss://[^/]+/room$' -and $ServerUrl -notmatch '^ws://(127\.0\.0\.1|localhost):\d+/room$') { throw 'Use WSS; WS só é permitido em loopback.' }
$taskRoot = Split-Path $PSScriptRoot -Parent
if (-not $Templates) { $Templates = Join-Path $taskRoot '.tools/godot-templates' }
if (-not (Test-Path (Join-Path $Templates '4.7.2/web_nothreads_release.zip'))) { throw 'Defina GODOT_WEB_TEMPLATES ou passe -Templates (pasta com 4.7.2/web_nothreads_release.zip).' }
if ($Fixture) { $AllowedUid = 'mp-a,mp-b' }
if ($AllowedUidsFile) { $AllowedUid = ((Get-Content -LiteralPath $AllowedUidsFile -Raw | ConvertFrom-Json).allowed_uids -join ',') }
$taskUids = @($AllowedUid.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($taskUids.Count -ne 2) { throw 'Use exatamente as duas contas já autorizadas.' }
$taskCopy = Join-Path $taskRoot $(if ($Fixture) { '.tools/multiplayer-fixture' } else { '.tools/multiplayer-export' })
$taskOutput = Join-Path $taskRoot $(if ($Fixture) { 'build/multiplayer-fixture' } else { 'build/multiplayer-pilot' })
New-Item -ItemType Directory -Force $taskCopy,$taskOutput | Out-Null
foreach ($taskName in @('scripts','scenes','web','config','assets','project.godot','icon.svg','export_presets.cfg')) {
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskName) -Destination $taskCopy -Recurse -Force
}
foreach ($taskName in @('world-sync','global-chat')) {
    $taskConfig = @{ enabled=(-not $Fixture); allowed_uids=$taskUids }
    if ($taskName -eq 'world-sync') { $taskConfig.interval_seconds = 120 }
    [IO.File]::WriteAllText((Join-Path $taskCopy "config/$taskName.json"),($taskConfig | ConvertTo-Json))
}
[IO.File]::WriteAllText((Join-Path $taskCopy 'config/multiplayer.json'),(@{enabled=$true;url=$ServerUrl;version='0.9.0-multiplayer-pilot.5'} | ConvertTo-Json))
$taskStamp = @{ version='0.9.0-multiplayer-pilot.5'; commit=(git -C $taskRoot rev-parse HEAD).Trim(); emulated=[bool]$Fixture; save_schema=8; base_release='0.9.0'; multiplayer_protocol=3; server_url=$ServerUrl }
[IO.File]::WriteAllText((Join-Path $taskCopy 'config/build-public.json'),($taskStamp | ConvertTo-Json))
$taskPreset = Join-Path $taskCopy 'export_presets.cfg'
$taskText = [IO.File]::ReadAllText($taskPreset).Replace('res://.tools/godot-templates/',($Templates.Replace('\','/')+'/'))
if ($Fixture) {
    New-Item -ItemType Directory -Force (Join-Path $taskCopy 'tests') | Out-Null
    Copy-Item -Path (Join-Path $taskRoot 'tests/multiplayer_fixture.*') -Destination (Join-Path $taskCopy 'tests') -Force
    $taskProject = Join-Path $taskCopy 'project.godot'
    [IO.File]::WriteAllText($taskProject, [IO.File]::ReadAllText($taskProject).Replace('res://scenes/main.tscn','res://tests/multiplayer_fixture.tscn'))
    $taskText = $taskText.Replace('tests/*,','')
}
[IO.File]::WriteAllText($taskPreset,$taskText)
foreach ($taskStage in @('import','export')) {
    $taskLog = Join-Path $taskRoot ".tools/multiplayer-$taskStage.log"
    $ErrorActionPreference = 'Continue'
    $taskPreviousAppData = $env:APPDATA
    $env:APPDATA = Join-Path $taskRoot '.tools/multiplayer-build-user'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    if ($taskStage -eq 'import') { & $Godot --headless --path $taskCopy --editor --import --quit *> $taskLog }
    else { & $Godot --headless --path $taskCopy --export-release Web (Join-Path $taskOutput 'index.html') *> $taskLog }
    $taskExit = $LASTEXITCODE
    $env:APPDATA = $taskPreviousAppData
    $ErrorActionPreference = 'Stop'
    if ($taskExit -ne 0 -or (Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR|Parse Error|Export failed' -Quiet)) { Get-Content $taskLog -Tail 55; throw "Falha no piloto: $taskStage" }
}
New-Item -ItemType Directory -Force (Join-Path $taskOutput 'assets/fonts') | Out-Null
Copy-Item -Path (Join-Path $taskRoot 'assets/fonts/*.ttf'),(Join-Path $taskRoot 'assets/fonts/*OFL.txt') -Destination (Join-Path $taskOutput 'assets/fonts') -Force
Copy-Item -LiteralPath (Join-Path $taskCopy 'config/build-public.json') -Destination (Join-Path $taskOutput 'version.json') -Force
Write-Output "Piloto exportado: $taskOutput"
