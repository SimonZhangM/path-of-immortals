$ErrorActionPreference = 'Stop'
$previewDirectory = $PSScriptRoot
$previewConfig = Get-Content -LiteralPath (Join-Path $previewDirectory 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$previewUrl = "http://127.0.0.1:$($previewConfig.port)"
try {
    $previewHealth = Invoke-RestMethod "$previewUrl/api/health" -TimeoutSec 2
    if ($previewHealth.app -ne 'local-spine-preview' -or $previewHealth.root -ne $previewConfig.root) { throw 'The configured port is used by a different application or library.' }
    Start-Process $previewUrl
    exit 0
} catch {
    if ($previewHealth) { throw }
}
$previewNode = Get-Command node.exe -ErrorAction SilentlyContinue
if (-not $previewNode) { throw 'Node.js 18+ is required. Install Node.js, then run this launcher again.' }
$previewLocal = Join-Path $previewDirectory '.local'
New-Item -ItemType Directory -Path $previewLocal -Force | Out-Null
$previewServer = Join-Path $previewDirectory 'server.mjs'
$previewProcess = Start-Process -FilePath $previewNode.Source -ArgumentList ('"' + $previewServer + '"') -WorkingDirectory $previewDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $previewLocal 'server.log') -RedirectStandardError (Join-Path $previewLocal 'server-error.log')
$previewProcess.Id | Set-Content -LiteralPath (Join-Path $previewLocal 'server.pid')
for ($previewTry = 0; $previewTry -lt 40; $previewTry++) {
    Start-Sleep -Milliseconds 250
    if ($previewProcess.HasExited) { throw (Get-Content -LiteralPath (Join-Path $previewLocal 'server-error.log') -Raw) }
    try { $previewHealth = Invoke-RestMethod "$previewUrl/api/health" -TimeoutSec 1 } catch { continue }
    if ($previewHealth.app -eq 'local-spine-preview' -and $previewHealth.pid -eq $previewProcess.Id) { Start-Process $previewUrl; exit 0 }
}
throw "The preview server did not start. See $previewLocal\server-error.log"
