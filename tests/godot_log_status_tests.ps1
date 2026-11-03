$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_log_status.ps1')
$rootError = "ERROR: Failed to read the root certificate store.`r`n   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)`r`n"
$builtin = "Loaded builtin CA certificates`r`nCHECKS PASSED`r`n"
$cases = @(
    @{Name='clean'; Code=0; Out='CHECKS PASSED'; Err=''; Failed=$false; Fallback=$false},
    @{Name='verified builtin fallback'; Code=0; Out=$builtin; Err=$rootError; Failed=$false; Fallback=$true},
    @{Name='missing fallback confirmation'; Code=0; Out=''; Err=$rootError; Failed=$true; Fallback=$false},
    @{Name='nonzero process exit'; Code=2; Out=$builtin; Err=$rootError; Failed=$true; Fallback=$true},
    @{Name='script error after fallback'; Code=0; Out=$builtin; Err=($rootError+'SCRIPT ERROR: broken script'); Failed=$true; Fallback=$true},
    @{Name='TLS handshake error after fallback'; Code=0; Out=$builtin; Err=($rootError+'ERROR: TLS handshake failed'); Failed=$true; Fallback=$true},
    @{Name='assertion on stdout'; Code=0; Out=($builtin+'FAIL: expected image'); Err=$rootError; Failed=$true; Fallback=$true},
    @{Name='same message from other source'; Code=0; Out=$builtin; Err=$rootError.Replace('platform/windows/os_windows.cpp','scripts/custom.gd'); Failed=$true; Fallback=$false},
    @{Name='LF line endings'; Code=0; Out=$builtin.Replace("`r",''); Err=$rootError.Replace("`r",''); Failed=$false; Fallback=$true},
    @{Name='unrelated engine error'; Code=0; Out=''; Err='ERROR: Cannot load texture'; Failed=$true; Fallback=$false}
)
foreach ($case in $cases) {
    $actual = Get-GodotLogStatus -ExitCode $case.Code -Stdout $case.Out -Stderr $case.Err
    if ($actual.Failed -ne $case.Failed -or $actual.CertificateFallback -ne $case.Fallback) {
        throw "Incorrect status: $($case.Name)"
    }
}
Write-Output "GODOT LOG CLASSIFICATION: $($cases.Count) cases passed"
