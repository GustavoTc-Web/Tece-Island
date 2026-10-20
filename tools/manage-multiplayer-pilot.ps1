param(
    [ValidateSet('Start','Stop','Status','RestartServer','RepairTunnel')][string]$Action = 'Status',
    [string]$AllowedUidsFile,
    [int]$Port = 8787
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskRuntime = Join-Path $taskRoot '.tools/mp-runtime.json'
$taskNode = [IO.Path]::GetFullPath((Get-Command node -ErrorAction Stop).Source)
$taskConnector = Join-Path $taskRoot '.tools/cloudflared.exe'
$taskOrigin = 'https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site'
$taskState = @{}
if (Test-Path -LiteralPath $taskRuntime) {
    $taskSaved = Get-Content -LiteralPath $taskRuntime -Raw | ConvertFrom-Json
    foreach ($taskProperty in $taskSaved.PSObject.Properties) { $taskState[$taskProperty.Name] = $taskProperty.Value }
}
function Save-State {
    New-Item -ItemType Directory -Force (Split-Path $taskRuntime -Parent) | Out-Null
    [IO.File]::WriteAllText(($taskRuntime+'.tmp'), ($taskState | ConvertTo-Json -Depth 5))
    Move-Item -LiteralPath ($taskRuntime+'.tmp') -Destination $taskRuntime -Force
}
function Owned-Process([string]$Kind, [string]$Executable) {
    $taskId = $taskState[$Kind+'_pid']
    if (-not $taskId) { return $null }
    $taskProcess = Get-Process -Id $taskId -ErrorAction SilentlyContinue
    if (-not $taskProcess) { return $null }
    if ([IO.Path]::GetFullPath($taskProcess.Path) -ine [IO.Path]::GetFullPath($Executable) -or $taskProcess.StartTime.ToUniversalTime().ToString('o') -ne $taskState[$Kind+'_started_at']) {
        throw "PID de $Kind foi reutilizado ou nao corresponde ao processo registrado; nenhum processo foi encerrado."
    }
    return $taskProcess
}
function Stop-Owned([string]$Kind, [string]$Executable) {
    $taskProcess = Owned-Process $Kind $Executable
    if ($taskProcess) { Stop-Process -Id $taskProcess.Id; $taskProcess.WaitForExit(5000) | Out-Null }
    $taskState[$Kind+'_pid'] = 0
    Save-State
}
function Show-State {
    $taskServer = Owned-Process 'server' $taskNode
    $taskTunnel = Owned-Process 'tunnel' $taskConnector
    $taskLocal = Test-Health "http://127.0.0.1:$($taskState.port)/health"
    $taskRemote = Test-Health (Health-Url $taskState.wss)
    [PSCustomObject]@{
        server_running = [bool]$taskServer; server_pid = $taskState.server_pid
        tunnel_running = [bool]$taskTunnel; tunnel_pid = $taskState.tunnel_pid
        server_healthy = $taskLocal; tunnel_healthy = $taskRemote
        port = $taskState.port; wss = $taskState.wss
        published_wss = $taskState.published_wss
        needs_republish = ($taskState.wss -ne $taskState.published_wss)
        published_endpoint_healthy = if ($taskState.published_wss -eq $taskState.wss) { $taskRemote } else { Test-Health (Health-Url $taskState.published_wss) }
    } | Format-List
}
function Health-Url([string]$Address) {
    if ($Address -notmatch '^wss://[a-z0-9-]+\.trycloudflare\.com/room$') { return '' }
    return $Address.Replace('wss://','https://').Replace('/room','/health')
}
function Test-Health([string]$Address) {
    if (-not $Address) { return $false }
    try {
        $taskResult = Invoke-RestMethod -Uri $Address -TimeoutSec 5
        return [bool]($taskResult.ok -and $taskResult.protocol -eq 1 -and $taskResult.version -like '0.9.0-multiplayer-pilot.*')
    } catch { return $false }
}
if ($Action -eq 'Status') { Show-State; exit 0 }
if ($Action -eq 'Stop') {
    Stop-Owned 'tunnel' $taskConnector
    Stop-Owned 'server' $taskNode
    Show-State
    exit 0
}
if ($taskState.port) { $Port = [int]$taskState.port }
if ($Action -eq 'RestartServer') { Stop-Owned 'server' $taskNode }
if (-not $AllowedUidsFile) { $AllowedUidsFile = $taskState.allowed_uids_file }
if (-not $AllowedUidsFile) { $AllowedUidsFile = Join-Path (Split-Path $taskRoot -Parent) 'solo-pilot-project/config/world-sync.json' }
$taskAccountsPath = (Resolve-Path -LiteralPath $AllowedUidsFile).Path
$taskAccounts = Get-Content -LiteralPath $taskAccountsPath -Raw | ConvertFrom-Json
if (@($taskAccounts.allowed_uids | Select-Object -Unique).Count -ne 2) { throw 'Use exatamente as duas contas autorizadas.' }
if ($env:FIREBASE_AUTH_EMULATOR_HOST -or $env:TECE_LOCAL_AUTH_TEST) { throw 'Nao execute o servidor remoto com variaveis de emulador.' }
if (-not (Owned-Process 'server' $taskNode)) {
    $taskProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try { $taskProbe.Start() } finally { $taskProbe.Stop() }
    $env:TECE_ALLOWED_UIDS_FILE = $taskAccountsPath
    $env:TECE_ORIGINS = $taskOrigin
    $env:TECE_BIND = '127.0.0.1'
    $env:PORT = [string]$Port
    $taskFirebase = Get-Content -LiteralPath (Join-Path $taskRoot 'config/firebase-public.json') -Raw | ConvertFrom-Json
    $env:TECE_FIREBASE_PROJECT = $taskFirebase.projectId
    $env:TECE_FIREBASE_API_KEY = $taskFirebase.apiKey
    Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS -ErrorAction SilentlyContinue
    $taskProcess = Start-Process -FilePath $taskNode -ArgumentList 'index.mjs' -WorkingDirectory (Join-Path $taskRoot 'server') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $taskRoot '.tools/mp-production.log') -RedirectStandardError (Join-Path $taskRoot '.tools/mp-production-error.log') -PassThru
    $taskState.server_pid = $taskProcess.Id
    $taskState.server_started_at = $taskProcess.StartTime.ToUniversalTime().ToString('o')
    $taskState.port = $Port
    $taskState.allowed_uids_file = $taskAccountsPath
    Save-State
    $taskHealthy = $false
    for ($taskAttempt=0; $taskAttempt -lt 40; $taskAttempt++) {
        if ($taskProcess.HasExited) { throw 'Servidor encerrou; consulte .tools/mp-production-error.log.' }
        try {
            $taskHealth = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 1
            if ($taskHealth.ok -and $taskHealth.protocol -eq 1 -and $taskHealth.version -eq '0.9.0-multiplayer-pilot.2') { $taskHealthy = $true; break }
        } catch { Start-Sleep -Milliseconds 100 }
    }
    if (-not $taskHealthy) { throw 'Servidor ainda nao confirmou health; o tunel nao foi aberto.' }
}
if (-not (Test-Health "http://127.0.0.1:$Port/health")) { throw 'Servidor local sem resposta; o tunel nao foi aberto. Use RestartServer e depois Start.' }
# A live cloudflared process can retain a deleted Quick Tunnel indefinitely.
# Repair the relay without restarting the authoritative room.
if ($Action -eq 'RepairTunnel' -or -not (Test-Health (Health-Url $taskState.wss))) {
    Stop-Owned 'tunnel' $taskConnector
}
if (-not (Owned-Process 'tunnel' $taskConnector)) {
    if ($Action -eq 'RestartServer') { Show-State; exit 0 }
    if ((Get-FileHash -LiteralPath $taskConnector -Algorithm SHA256).Hash.ToLowerInvariant() -ne '4d2490e74082c5d48dbfedaf92576fa5bd1702379ab88eb7faa0cfbe8dc891b6') { throw 'Conector diferente do binario oficial verificado; revise a instalacao antes de abrir o tunel.' }
    $taskProcess = Start-Process -FilePath $taskConnector -ArgumentList @('tunnel','--url',"http://127.0.0.1:$Port",'--no-autoupdate','--protocol','http2') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $taskRoot '.tools/mp-tunnel.log') -RedirectStandardError (Join-Path $taskRoot '.tools/mp-tunnel-error.log') -PassThru
    $taskState.tunnel_pid = $taskProcess.Id
    $taskState.tunnel_started_at = $taskProcess.StartTime.ToUniversalTime().ToString('o')
    $taskState.wss = ''
    Save-State
    for ($taskAttempt=0; $taskAttempt -lt 180; $taskAttempt++) {
        if ($taskProcess.HasExited) { throw 'Tunel encerrou; consulte .tools/mp-tunnel-error.log.' }
        $taskText = (Get-Content -LiteralPath (Join-Path $taskRoot '.tools/mp-tunnel-error.log') -Raw -ErrorAction SilentlyContinue)
        if ($taskText -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
            $taskState.wss = $Matches[0].Replace('https://','wss://') + '/room'
            Save-State
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $taskState.wss) { throw 'Endereco ainda nao confirmado. Consulte Status/log antes de repetir Start.' }
    # Avoid caching NXDOMAIN while Quick Tunnel is still registering its route.
    $taskRegistered = $false
    for ($taskAttempt=0; $taskAttempt -lt 240; $taskAttempt++) {
        if ($taskProcess.HasExited) { throw 'Tunel encerrou durante o registro.' }
        if (Select-String -LiteralPath (Join-Path $taskRoot '.tools/mp-tunnel-error.log') -SimpleMatch 'Registered tunnel connection' -Quiet) { $taskRegistered = $true; break }
        Start-Sleep -Milliseconds 250
    }
    if (-not $taskRegistered) { throw 'Processo ativo, mas nenhum relay registrado; nao publique este endereco.' }
    $taskRelayHealthy = $false
    for ($taskAttempt=0; $taskAttempt -lt 12; $taskAttempt++) {
        if (Test-Health (Health-Url $taskState.wss)) { $taskRelayHealthy = $true; break }
        Start-Sleep -Milliseconds 2500
    }
    if (-not $taskRelayHealthy) { throw 'Tunel criado, mas HTTPS ainda nao responde; Status deve confirmar tunnel_healthy antes da publicacao.' }
}
Show-State
