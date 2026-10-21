param([ValidatePattern('^[a-z0-9-]+$')][string]$Instance='mp')
$ErrorActionPreference='Stop'
$hostRoot=Split-Path $PSScriptRoot -Parent
$hostQueue=Join-Path $hostRoot ('.tools/'+$Instance+'-host')
New-Item -ItemType Directory -Force $hostQueue | Out-Null
$hostLog=Join-Path $hostQueue 'events.jsonl'
function Host-Event([string]$Event,[string]$Code='') {
    [IO.File]::AppendAllText($hostLog,(@{at=[DateTime]::UtcNow.ToString('o');event=$Event;code=$Code}|ConvertTo-Json -Compress)+[Environment]::NewLine)
}
# On-demand task, running as the logged-in user. No logon/startup trigger,
# elevation, password, secret, billing, or automatic room resets.
Host-Event 'host_started'
$hostLastHealth=[DateTime]::MinValue
while($true) {
    $hostRequests=@(Get-ChildItem -LiteralPath $hostQueue -Filter '*.request.json' -File | Sort-Object Name)
    foreach($hostRequest in $hostRequests) {
        $hostId=$hostRequest.BaseName.Replace('.request','')
        if($hostId -notmatch '^[a-f0-9]{32}$'){continue}
        $hostReply=@{id=$hostId;ok=$false;code='host_request_failed'}
        try {
            $hostInput=Get-Content -LiteralPath $hostRequest.FullName -Raw | ConvertFrom-Json
            if($hostInput.action -notin @('Start','RestartServer','RepairTunnel')){throw 'Invalid host action'}
            $hostArgs=@{Action=[string]$hostInput.action;Instance=$Instance;ManagedChild=$true}
            if($hostInput.allowed_file){$hostArgs.AllowedUidsFile=[string]$hostInput.allowed_file}
            if($hostInput.port){$hostArgs.Port=[int]$hostInput.port}
            Host-Event 'operation_started' $hostInput.action
            & (Join-Path $PSScriptRoot 'manage-multiplayer-pilot.ps1') @hostArgs | Out-Null
            $hostReply.ok=$true;$hostReply.code='completed'
            Host-Event 'operation_completed' $hostInput.action
        } catch {
            # Fixed codes only: never serialize exception payloads or identities.
            Host-Event 'operation_failed' 'inspect_local_and_tunnel_logs'
        }
        [IO.File]::WriteAllText((Join-Path $hostQueue ($hostId+'.reply.json')),($hostReply|ConvertTo-Json -Compress))
        Remove-Item -LiteralPath $hostRequest.FullName
    }
    if(([DateTime]::UtcNow-$hostLastHealth).TotalSeconds -gt 15){
        $hostLastHealth=[DateTime]::UtcNow
        # Monitoring is diagnostic only: restarting a room requires an explicit
        # command so its RAM is never silently reset by a watchdog.
        $hostStatePath=Join-Path $hostRoot ('.tools/'+$Instance+'-runtime.json')
        if(Test-Path -LiteralPath $hostStatePath){
            try {
                $hostState=Get-Content -LiteralPath $hostStatePath -Raw | ConvertFrom-Json
                $hostAlive=Get-Process -Id $hostState.server_pid -ErrorAction SilentlyContinue
                if(-not $hostAlive){Host-Event 'server_not_running'}
                $hostRelay=Get-Process -Id $hostState.tunnel_pid -ErrorAction SilentlyContinue
                if(-not $hostRelay){Host-Event 'tunnel_not_running'}
            } catch {Host-Event 'monitor_failed' 'state_unavailable'}
        }
    }
    Start-Sleep -Milliseconds 250
}
