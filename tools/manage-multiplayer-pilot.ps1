param(
    [ValidateSet('Start','Stop','Status','RestartServer','RepairTunnel')][string]$Action = 'Status',
    [string]$AllowedUidsFile,
    [int]$Port = 8787,
    [ValidatePattern('^[a-z0-9-]+$')][string]$Instance = 'mp',
    [switch]$ManagedChild,
    [switch]$PublishEndpoint
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskRuntime = Join-Path $taskRoot ('.tools/'+$Instance+'-runtime.json')
$taskNode = [IO.Path]::GetFullPath((Get-Command node -ErrorAction Stop).Source)
$taskConnector = Join-Path $taskRoot '.tools/cloudflared.exe'
$taskOrigin = 'https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site'
$taskHostName='TeceIsland-Multiplayer-'+$Instance
$taskHostScript=Join-Path $PSScriptRoot 'multiplayer-host.ps1'
$taskShell=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$taskHostArguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$taskHostScript+'" -Instance '+$Instance
$taskDiscoveryUrl='https://raw.githubusercontent.com/GustavoTc-Web/Tece-Island/refs/heads/feat/multiplayer-pilot/runtime/multiplayer-endpoint.json'
$taskExpectedVersion='0.9.0-multiplayer-pilot.6'
function Owned-Host {
    $taskHost=Get-ScheduledTask -TaskName $taskHostName -ErrorAction SilentlyContinue
    if($taskHost -and ($taskHost.Actions.Count -ne 1 -or $taskHost.Actions[0].Execute -ine $taskShell -or $taskHost.Actions[0].Arguments -ne $taskHostArguments)){
        throw 'A tarefa existente nao corresponde ao host deste checkout; nada foi alterado.'
    }
    return $taskHost
}
$taskState = @{}
if (Test-Path -LiteralPath $taskRuntime) {
    $taskSaved = Get-Content -LiteralPath $taskRuntime -Raw | ConvertFrom-Json
    foreach ($taskProperty in $taskSaved.PSObject.Properties) { $taskState[$taskProperty.Name] = $taskProperty.Value }
}
$taskLogPrefix = if ($taskState.log_prefix) { [string]$taskState.log_prefix } else { $Instance }
if ($taskLogPrefix -notmatch '^[a-z0-9-]+$') { throw 'Prefixo de log invalido.' }
function Task-Log([string]$Name) { return Join-Path $taskRoot ('.tools/'+$taskLogPrefix+'-'+$Name+'.log') }
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
        Write-Warning "PID de $Kind nao pertence mais a esta instancia; o processo existente foi preservado."
        return $null
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
    $taskInfo=$null
    try{$taskInfo=Invoke-RestMethod -Uri "http://127.0.0.1:$($taskState.port)/health" -TimeoutSec 3}catch{}
    $taskTransport=$null
    if($taskRemote){try{$taskTransport=(& $taskNode (Join-Path $PSScriptRoot 'probe-multiplayer-transport.mjs') $taskState.wss | ConvertFrom-Json)}catch{}}
    $taskPublished=$null
    try{$taskPublished=Invoke-RestMethod -Uri ($taskDiscoveryUrl+'?t='+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -TimeoutSec 8}catch{}
    $taskRouteMatches=[bool]($taskPublished.schema -eq 1 -and $taskPublished.protocol -eq 3 -and $taskPublished.url -eq $taskState.wss)
    $taskClientCurrent=[bool]($taskState.published_client_version -eq $taskExpectedVersion)
    $script:taskReady=[bool]($taskServer -and $taskTunnel -and $taskLocal -and $taskTransport.wss -and $taskRouteMatches -and $taskClientCurrent -and $taskInfo.version -eq $taskExpectedVersion -and $taskInfo.protocol -eq 3)
    [PSCustomObject]@{
        host_task = $taskHostName; host_running = [bool]((Owned-Host).State -eq 'Running')
        server_version = $taskInfo.version; server_protocol = $taskInfo.protocol
        expected_version = $taskExpectedVersion
        version_matches = [bool]($taskInfo.version -eq $taskExpectedVersion -and $taskInfo.protocol -eq 3)
        server_running = [bool]$taskServer; server_pid = $taskState.server_pid
        tunnel_running = [bool]$taskTunnel; tunnel_pid = $taskState.tunnel_pid
        server_healthy = $taskLocal; tunnel_healthy = $taskRemote
        port = $taskState.port; wss = $taskState.wss
        published_wss = $taskState.published_wss
        wss_healthy = [bool]$taskTransport.wss
        endpoint_config_matches = $taskRouteMatches
        published_client_version = $taskState.published_client_version
        needs_republish = -not $taskClientCurrent
        needs_endpoint_publish = -not $taskRouteMatches
        ready_to_play = $script:taskReady
        published_endpoint_healthy = if ($taskState.published_wss -eq $taskState.wss) { $taskRemote } else { Test-Health (Health-Url $taskState.published_wss) }
    } | Format-List
}
function Publish-Endpoint {
    if(-not (Test-Health (Health-Url $taskState.wss))){throw 'HTTPS indisponivel; nenhum endereco foi publicado.'}
    $taskTransport=& $taskNode (Join-Path $PSScriptRoot 'probe-multiplayer-transport.mjs') $taskState.wss | ConvertFrom-Json
    if(-not $taskTransport.wss -or $taskTransport.version -ne $taskExpectedVersion -or $taskTransport.protocol -ne 3){throw 'WSS/versao nao confirmados; nenhum endereco foi publicado.'}
    $taskBranch=(& git -C $taskRoot branch --show-current).Trim()
    $taskRemoteUrl=(& git -C $taskRoot remote get-url origin).Trim()
    if($taskBranch -ne 'feat/multiplayer-pilot' -or $taskRemoteUrl -notmatch '^(https://github.com/|git@github.com:)GustavoTc-Web/Tece-Island(\.git)?$'){throw 'Checkout inesperado; publicacao de endereco cancelada.'}
    $taskRoutePath=Join-Path $taskRoot 'runtime/multiplayer-endpoint.json'
    New-Item -ItemType Directory -Force (Split-Path $taskRoutePath -Parent) | Out-Null
    $taskRoute=[ordered]@{schema=1;protocol=3;url=[string]$taskState.wss}
    $taskExistingRoute=$null
    if(Test-Path -LiteralPath $taskRoutePath){try{$taskExistingRoute=Get-Content -LiteralPath $taskRoutePath -Raw|ConvertFrom-Json}catch{}}
    if($taskExistingRoute.schema -ne 1 -or $taskExistingRoute.protocol -ne 3 -or $taskExistingRoute.url -ne $taskState.wss){
        [IO.File]::WriteAllText($taskRoutePath,($taskRoute|ConvertTo-Json)+[Environment]::NewLine)
    }
    & git -C $taskRoot diff --quiet HEAD -- runtime/multiplayer-endpoint.json
    $taskRouteTracked=& git -C $taskRoot ls-files -- runtime/multiplayer-endpoint.json
    if($LASTEXITCODE -ne 0){throw 'Falha ao conferir o arquivo publico de endereco.'}
    if(-not $taskRouteTracked -or (& git -C $taskRoot diff HEAD -- runtime/multiplayer-endpoint.json)){
        & git -C $taskRoot add -- runtime/multiplayer-endpoint.json
        if($LASTEXITCODE -ne 0){throw 'Falha ao preparar endereco.'}
        & git -C $taskRoot commit --only -m 'ops(multiplayer): publish current temporary game endpoint' -- runtime/multiplayer-endpoint.json
        if($LASTEXITCODE -ne 0){throw 'Falha ao registrar endereco; os servicos continuam ativos.'}
    }
    & git -C $taskRoot push origin HEAD:refs/heads/feat/multiplayer-pilot
    if($LASTEXITCODE -ne 0){throw 'Push do endereco falhou. Os servicos continuam ativos; repita Start -PublishEndpoint apos recuperar o acesso ao GitHub.'}
    $taskState.discovery_url=$taskDiscoveryUrl
    Save-State
}
function Health-Url([string]$Address) {
    if ($Address -notmatch '^wss://[a-z0-9-]+\.trycloudflare\.com/room$') { return '' }
    return $Address.Replace('wss://','https://').Replace('/room','/health')
}
function Test-Health([string]$Address) {
    if (-not $Address) { return $false }
    try {
        $taskResult = Invoke-RestMethod -Uri $Address -TimeoutSec 5
        return [bool]($taskResult.ok -and $taskResult.protocol -in @(2,3) -and $taskResult.version -like '0.9.0-multiplayer-pilot.*')
    } catch { return $false }
}
if ($Action -eq 'Status') { Show-State; if(-not $script:taskReady){exit 2}; exit 0 }
if ($Action -eq 'Stop') {
    if(-not $ManagedChild -and (Owned-Host)){Stop-ScheduledTask -TaskName $taskHostName}
    Stop-Owned 'tunnel' $taskConnector
    Stop-Owned 'server' $taskNode
    Show-State
    exit 0
}
if(-not $ManagedChild){
    if(-not (Owned-Host)){
        $taskIdentity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
        $taskHostAction=New-ScheduledTaskAction -Execute $taskShell -Argument $taskHostArguments -WorkingDirectory $taskRoot
        $taskPrincipal=New-ScheduledTaskPrincipal -UserId $taskIdentity -LogonType Interactive -RunLevel Limited
        $taskSettings=New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskHostName -Action $taskHostAction -Principal $taskPrincipal -Settings $taskSettings -Description 'Host local sob demanda do piloto privado Tece-Island. Sem inicio automatico e sem credenciais salvas.' | Out-Null
    }
    $taskQueue=Join-Path $taskRoot ('.tools/'+$Instance+'-host')
    New-Item -ItemType Directory -Force $taskQueue | Out-Null
    $taskRequestId=[Guid]::NewGuid().ToString('N')
    $taskRequest=@{action=$Action;allowed_file=$AllowedUidsFile;port=$Port}
    [IO.File]::WriteAllText((Join-Path $taskQueue ($taskRequestId+'.request.json')),($taskRequest|ConvertTo-Json -Compress))
    if((Owned-Host).State -ne 'Running'){Start-ScheduledTask -TaskName $taskHostName}
    $taskReplyFile=Join-Path $taskQueue ($taskRequestId+'.reply.json')
    $taskDeadline=[DateTime]::UtcNow.AddSeconds(150)
    while(-not (Test-Path -LiteralPath $taskReplyFile) -and [DateTime]::UtcNow -lt $taskDeadline){Start-Sleep -Milliseconds 250}
    if(-not (Test-Path -LiteralPath $taskReplyFile)){throw 'Host ainda nao confirmou a operacao; consulte Status e .tools/*-host/events.jsonl antes de repetir.'}
    $taskReply=Get-Content -LiteralPath $taskReplyFile -Raw | ConvertFrom-Json
    if(-not $taskReply.ok){throw 'Host nao concluiu a operacao; consulte Status e os logs locais antes de repetir.'}
    $taskSaved=Get-Content -LiteralPath $taskRuntime -Raw | ConvertFrom-Json
    foreach($taskProperty in $taskSaved.PSObject.Properties){$taskState[$taskProperty.Name]=$taskProperty.Value}
    if($PublishEndpoint){Publish-Endpoint}
    Show-State
    if(-not $script:taskReady){Write-Warning 'Piloto ainda nao esta pronto. Confira needs_republish e needs_endpoint_publish; nao reinicie a sala para corrigir apenas o endereco.';exit 2}
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
    $taskProcess = Start-Process -FilePath $taskNode -ArgumentList 'index.mjs' -WorkingDirectory (Join-Path $taskRoot 'server') -WindowStyle Hidden -RedirectStandardOutput (Task-Log 'production') -RedirectStandardError (Task-Log 'production-error') -PassThru
    $taskState.server_pid = $taskProcess.Id
    $taskState.server_started_at = $taskProcess.StartTime.ToUniversalTime().ToString('o')
    $taskState.port = $Port
    $taskState.allowed_uids_file = $taskAccountsPath
    $taskState.log_prefix = $taskLogPrefix
    Save-State
    $taskHealthy = $false
    for ($taskAttempt=0; $taskAttempt -lt 40; $taskAttempt++) {
        if ($taskProcess.HasExited) { throw 'Servidor encerrou; consulte o log production-error da instancia.' }
        try {
            $taskHealth = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 1
            if ($taskHealth.ok -and $taskHealth.protocol -eq 3 -and $taskHealth.version -eq $taskExpectedVersion) { $taskHealthy = $true; break }
        } catch { Start-Sleep -Milliseconds 100 }
    }
    if (-not $taskHealthy) { throw 'Servidor ainda nao confirmou health; o tunel nao foi aberto.' }
}
if (-not (Test-Health "http://127.0.0.1:$Port/health")) { throw 'Servidor local sem resposta; o tunel nao foi aberto. Use RestartServer e depois Start.' }
# A live cloudflared process can retain a deleted Quick Tunnel indefinitely.
# Repair the relay without restarting the authoritative room.
if ($Action -eq 'RepairTunnel') {
    Stop-Owned 'tunnel' $taskConnector
}
elseif((Owned-Process 'tunnel' $taskConnector) -and -not (Test-Health (Health-Url $taskState.wss))){
    throw 'Processo do tunel ativo, mas HTTPS falhou. Confira rede/logs e Status; RepairTunnel -PublishEndpoint troca apenas o tunel, preservando a sala.'
}
if (-not (Owned-Process 'tunnel' $taskConnector)) {
    if ($Action -eq 'RestartServer') { Show-State; exit 0 }
    if ((Get-FileHash -LiteralPath $taskConnector -Algorithm SHA256).Hash.ToLowerInvariant() -ne '4d2490e74082c5d48dbfedaf92576fa5bd1702379ab88eb7faa0cfbe8dc891b6') { throw 'Conector diferente do binario oficial verificado; revise a instalacao antes de abrir o tunel.' }
    $taskProcess = Start-Process -FilePath $taskConnector -ArgumentList @('tunnel','--url',"http://127.0.0.1:$Port",'--no-autoupdate','--protocol','http2','--edge-ip-version','4') -WindowStyle Hidden -RedirectStandardOutput (Task-Log 'tunnel') -RedirectStandardError (Task-Log 'tunnel-error') -PassThru
    $taskState.tunnel_pid = $taskProcess.Id
    $taskState.tunnel_started_at = $taskProcess.StartTime.ToUniversalTime().ToString('o')
    $taskState.wss = ''
    Save-State
    for ($taskAttempt=0; $taskAttempt -lt 180; $taskAttempt++) {
        if ($taskProcess.HasExited) { throw 'Tunel encerrou; consulte o log tunnel-error da instancia.' }
        $taskText = (Get-Content -LiteralPath (Task-Log 'tunnel-error') -Raw -ErrorAction SilentlyContinue)
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
        if (Select-String -LiteralPath (Task-Log 'tunnel-error') -SimpleMatch 'Registered tunnel connection' -Quiet) { $taskRegistered = $true; break }
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
