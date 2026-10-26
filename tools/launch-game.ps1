param(
    [ValidateSet('direct', 'start', 'preparation')][string]$Entry = 'direct',
    [string]$GodotPath = $env:GODOT_EXE,
    [switch]$Describe
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$entries = @{
    direct = 'res://scenes/maps/session_start.tscn'
    start = 'res://scenes/entry/start_menu.tscn'
    preparation = 'res://scenes/entry/character_preparation.tscn'
}
if (-not $GodotPath) {
    $nearby = Join-Path (Split-Path -Parent $projectRoot) 'Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $nearby -PathType Leaf) { $GodotPath = $nearby }
    else {
        $command = Get-Command godot.exe -ErrorAction SilentlyContinue
        if ($command) { $GodotPath = $command.Source }
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot was not found. Set GODOT_EXE to your Godot executable path, then launch again.'
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$scene = $entries[$Entry]
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $scene.Substring(6)) -PathType Leaf)) {
    throw "Entry scene is missing: $scene"
}
$launchArguments = @('--path', $projectRoot, $scene)
if ($Entry -ne 'direct') {
    $launchArguments += @('--', '--loadout-save=user://entry_flow_preview.json')
}
if ($Describe) {
    [pscustomobject]@{ entry = $Entry; executable = $GodotPath; arguments = $launchArguments } | ConvertTo-Json -Depth 3
    exit 0
}
# Start-Process joins ArgumentList; quote each token to preserve paths with spaces.
$quotedArguments = foreach ($argument in $launchArguments) {
    if ($argument -match '["\r\n]') { throw 'A launch argument contains an unsupported quote or newline.' }
    '"' + $argument + '"'
}
# These launchers explicitly open a visible interactive game window.
Start-Process -FilePath $GodotPath -ArgumentList ($quotedArguments -join ' ') -WorkingDirectory $projectRoot -WindowStyle Normal | Out-Null
