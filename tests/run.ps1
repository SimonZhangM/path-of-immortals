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
Invoke-GodotCheck -Name 'item-cultivation-access' -ExtraArgs @('--headless', '--script', 'res://tests/item_cultivation_access.gd')
Invoke-GodotCheck -Name 'ui' -ExtraArgs @('--headless', '--script', 'res://tests/ui_smoke.gd')
Invoke-GodotCheck -Name 'map' -ExtraArgs @('--headless', '--script', 'res://tests/map_smoke.gd')
Invoke-GodotCheck -Name 'map-travel' -ExtraArgs @('--headless', '--script', 'res://tests/map_travel_tests.gd')
Invoke-GodotCheck -Name 'map-player' -ExtraArgs @('--headless', '--script', 'res://tests/map_player_smoke.gd')
Invoke-GodotCheck -Name 'map-player-animation' -ExtraArgs @('--headless', '--script', 'res://tests/map_player_animation.gd')
Invoke-GodotCheck -Name 'map-header' -ExtraArgs @('--headless', '--script', 'res://tests/map_header_smoke.gd')
Invoke-GodotCheck -Name 'map-inventory' -ExtraArgs @('--headless', '--script', 'res://tests/map_inventory_smoke.gd')
Invoke-GodotCheck -Name 'map-inventory-variants' -ExtraArgs @('--headless', '--script', 'res://tests/map_inventory_variants_smoke.gd')
Invoke-GodotCheck -Name 'map-inventory-transfer' -ExtraArgs @('--headless', '--script', 'res://tests/map_inventory_transfer_performance.gd')
Invoke-GodotCheck -Name 'map-loadout' -ExtraArgs @('--headless', '--script', 'res://tests/map_loadout_smoke.gd')
Invoke-GodotCheck -Name 'map-formation' -ExtraArgs @('--headless', '--script', 'res://tests/map_formation_smoke.gd')
Invoke-GodotCheck -Name 'armor-pool' -ExtraArgs @('--headless', '--script', 'res://tests/armor_pool_tests.gd')
Invoke-GodotCheck -Name 'support-effects' -ExtraArgs @('--headless', '--script', 'res://tests/support_effects_tests.gd')
Invoke-GodotCheck -Name 'damage-toxin' -ExtraArgs @('--headless', '--script', 'res://tests/damage_toxin_tests.gd')
Invoke-GodotCheck -Name 'item-tooltips' -ExtraArgs @('--headless', '--script', 'res://tests/item_tooltip_presentation.gd')
Invoke-GodotCheck -Name 'buff-sidebar' -ExtraArgs @('--headless', '--script', 'res://tests/map_buff_sidebar.gd')
Invoke-GodotCheck -Name 'inventory-categories' -ExtraArgs @('--headless', '--script', 'res://tests/map_inventory_categories.gd')
Invoke-GodotCheck -Name 'map-events' -ExtraArgs @('--headless', '--script', 'res://tests/map_event_tests.gd')
Invoke-GodotCheck -Name 'map-story-reward' -ExtraArgs @('--headless', '--script', 'res://tests/map_story_reward.gd')
Invoke-GodotCheck -Name 'map-dialogue' -ExtraArgs @('--headless', '--script', 'res://tests/map_dialogue_smoke.gd')
Invoke-GodotCheck -Name 'map-illustrated-dialogue' -ExtraArgs @('--headless', '--script', 'res://tests/map_illustrated_dialogue_smoke.gd')
Invoke-GodotCheck -Name 'startup' -ExtraArgs @('--headless', '--quit-after', '5', '--', '--loadout-save=')
Invoke-GodotCheck -Name 'battle-startup' -ExtraArgs @('--headless', 'res://scenes/main/main.tscn', '--quit-after', '5', '--', '--loadout-save=')
Invoke-GodotCheck -Name 'retreat-exit' -ExtraArgs @('--headless', '--script', 'res://tests/retreat_exit_smoke.gd')
if ($Render) {
    Invoke-GodotCheck -Name 'map-editor' -ExtraArgs @('--editor', 'res://scenes/maps/qingshihewan_layout.tscn', '--quit-after', '120')
    Invoke-GodotCheck -Name 'render' -ExtraArgs @('--script', 'res://tests/ui_smoke.gd')
    Invoke-GodotCheck -Name 'map-render' -ExtraArgs @('--script', 'res://tests/map_smoke.gd')
    Invoke-GodotCheck -Name 'map-player-render' -ExtraArgs @('--script', 'res://tests/map_player_smoke.gd')
    Invoke-GodotCheck -Name 'map-header-render' -ExtraArgs @('--script', 'res://tests/map_header_smoke.gd')
    Invoke-GodotCheck -Name 'map-inventory-render' -ExtraArgs @('--script', 'res://tests/map_inventory_smoke.gd')
    Invoke-GodotCheck -Name 'map-loadout-render' -ExtraArgs @('--script', 'res://tests/map_loadout_smoke.gd')
    Invoke-GodotCheck -Name 'map-formation-render' -ExtraArgs @('--script', 'res://tests/map_formation_smoke.gd')
    Invoke-GodotCheck -Name 'map-dialogue-render' -ExtraArgs @('--script', 'res://tests/map_dialogue_smoke.gd')
    Invoke-GodotCheck -Name 'map-illustrated-dialogue-render' -ExtraArgs @('--script', 'res://tests/map_illustrated_dialogue_smoke.gd')
}
Write-Output 'All Godot checks passed.'
