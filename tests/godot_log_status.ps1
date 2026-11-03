function Get-GodotLogStatus {
    param(
        [int]$ExitCode,
        [AllowEmptyString()][string]$Stdout,
        [AllowEmptyString()][string]$Stderr
    )

    # Preserve raw logs. Only classify this exact Windows startup failure when
    # Godot explicitly confirms that its verified-CA fallback was loaded.
    $hasBuiltinCertificates = $Stdout -match '(?m)^Loaded builtin CA certificates\r?$'
    $rootStoreError = '(?m)^ERROR: Failed to read the root certificate store\.\r?\n[ \t]+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?(?:\n|$)'
    $fallbackUsed = $hasBuiltinCertificates -and $Stderr -match $rootStoreError
    $effectiveErrors = $Stderr
    if ($fallbackUsed) {
        $effectiveErrors = [regex]::Replace($effectiveErrors, $rootStoreError, '')
    }
    $failed = $ExitCode -ne 0 -or ($Stdout + "`n" + $effectiveErrors) -match 'SCRIPT ERROR:|ERROR:|FAIL:'
    [pscustomobject]@{
        Failed = $failed
        CertificateFallback = $fallbackUsed
        ExitCode = $ExitCode
    }
}
