param(
    [Parameter(Mandatory=$true)][string]$AllowedUidsFile,
    [string]$Origins = 'http://localhost:8060,http://127.0.0.1:8060',
    [int]$Port = 8787
)
$ErrorActionPreference = 'Stop'
if ($env:FIREBASE_AUTH_EMULATOR_HOST -or $env:TECE_LOCAL_AUTH_TEST) { throw 'Abra um terminal sem variáveis de emulador para o servidor das contas reais.' }
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskConfig = Get-Content -LiteralPath $AllowedUidsFile -Raw | ConvertFrom-Json
if (@($taskConfig.allowed_uids | Select-Object -Unique).Count -ne 2) { throw 'O arquivo precisa conter exatamente os dois UIDs autorizados em allowed_uids.' }
$env:TECE_ALLOWED_UIDS_FILE = (Resolve-Path -LiteralPath $AllowedUidsFile).Path
$env:TECE_ORIGINS = $Origins
$env:TECE_BIND = '127.0.0.1'
$env:PORT = [string]$Port
Push-Location (Join-Path $taskRoot 'server')
try { & node index.mjs; exit $LASTEXITCODE } finally { Pop-Location }
