param([string]$Script = 'res://tests/t01_integration_tests.gd', [switch]$Import, [switch]$Render)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_log_status.ps1')
New-Item -ItemType Directory -Force -Path (Join-Path $root 'artifacts') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $root 'artifacts/.gdignore') | Out-Null
$arguments = @('--path', $root, '--verbose')
if (-not $Render) { $arguments += '--headless' }
else { $arguments += @('--rendering-method', 'gl_compatibility', '--display-driver', 'windows', '--windowed', '--resolution', '1920x1080') }
if ($Import) { $arguments += @('--editor', '--import', '--quit') }
else { $arguments += @('--script', $Script) }
$label = if ($Import) { 't01-import' } else { [System.IO.Path]::GetFileNameWithoutExtension($Script) }
$stdout = Join-Path $root "artifacts/$label.stdout.log"
$stderr = Join-Path $root "artifacts/$label.stderr.log"
$process = Start-Process -FilePath 'E:\games\Godot_v4.7.2-stable_win64.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
# Retain the native process handle so ExitCode remains available after a fast exit.
$null = $process.Handle
if (-not $process.WaitForExit(60000)) { Stop-Process -Id $process.Id; throw 'T01 check timed out' }
$outputText = Get-Content -LiteralPath $stdout -Encoding UTF8 -Raw
if ($outputText) { Write-Output $outputText }
$errorsText = Get-Content -LiteralPath $stderr -Encoding UTF8 -Raw
if ($errorsText) { Write-Output $errorsText }
if ($null -eq $process.ExitCode) { throw 'T01 check failed: Godot exit code unavailable' }
$status = Get-GodotLogStatus -ExitCode $process.ExitCode -Stdout $outputText -Stderr $errorsText
if ($status.CertificateFallback) {
    Write-Warning 'Godot could not open the Windows root store and loaded its builtin CA certificates. TLS verification remains enabled; Windows-only/private CA trust is not verified by this run.'
}
if ($status.Failed) { throw 'T01 check failed' }
