$ErrorActionPreference = 'Stop'
$previewPidFile = Join-Path $PSScriptRoot '.local/server.pid'
if (-not (Test-Path -LiteralPath $previewPidFile)) { Write-Host 'No managed preview server is running.'; exit 0 }
$previewProcessId = [int](Get-Content -LiteralPath $previewPidFile)
$previewProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $previewProcessId"
$previewServer = Join-Path $PSScriptRoot 'server.mjs'
if ($previewProcess -and $previewProcess.Name -eq 'node.exe' -and $previewProcess.CommandLine.Contains($previewServer)) {
    Stop-Process -Id $previewProcessId
    Write-Host 'Spine preview server stopped.'
}
Remove-Item -LiteralPath $previewPidFile
