param(
    [string]$GodotPath = 'E:\games\Godot_v4.7.2-stable_win64.exe',
    [switch]$Render
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $projectPath 'artifacts'
New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $artifactPath '.gdignore') | Out-Null
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath. Use -GodotPath to specify it."
}

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$ExtraArgs)
    $stdoutPath = Join-Path $artifactPath "$Name.stdout.log"
    $stderrPath = Join-Path $artifactPath "$Name.stderr.log"
    # Start-Process waits correctly for the Windows GUI executable as well.
    $engineArgs = @('--path', ('"' + $projectPath + '"')) + $ExtraArgs
    $run = Start-Process -FilePath $GodotPath -ArgumentList $engineArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $null = $run.Handle
    if (-not $run.WaitForExit(60000)) {
        Stop-Process -Id $run.Id
        throw "$Name timed out; see $artifactPath"
    }
    Get-Content -LiteralPath $stdoutPath -Encoding UTF8
    $errorText = Get-Content -LiteralPath $stderrPath -Encoding UTF8 -Raw
    if ($errorText) { Write-Output $errorText }
    if ($run.ExitCode -ne 0 -or $errorText -match '(?m)(SCRIPT ERROR:|ERROR:|FAIL:)') {
        throw "$Name failed (exit $($run.ExitCode)); see $artifactPath"
    }
}

Invoke-GodotCheck -Name 'import' -ExtraArgs @('--headless', '--editor', '--import', '--quit')
Invoke-GodotCheck -Name 'tests' -ExtraArgs @('--headless', '--script', 'res://tests/run_tests.gd')
Invoke-GodotCheck -Name 'ui' -ExtraArgs @('--headless', '--script', 'res://tests/ui_smoke.gd')
Invoke-GodotCheck -Name 'startup' -ExtraArgs @('--headless', '--quit-after', '5')
if ($Render) {
    Invoke-GodotCheck -Name 'render' -ExtraArgs @('--script', 'res://tests/ui_smoke.gd')
}
Write-Output 'All Godot checks passed.'
