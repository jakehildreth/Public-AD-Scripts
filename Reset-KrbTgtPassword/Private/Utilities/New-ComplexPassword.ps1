function New-ComplexPassword {
    <#
    .SYNOPSIS
        Generates a cryptographically random complex password
    
    .DESCRIPTION
        Generates a complex password using RNGCryptoServiceProvider that meets
        Windows password complexity requirements. The password will contain characters
        from at least 3 of the 4 categories (uppercase, lowercase, numbers, special characters).
        This function replaces the 'generateNewComplexPassword' function from the original script.
    
    .PARAMETER Length
        The desired password length (default: 64)
    
    .PARAMETER MaxAttempts
        Maximum generation attempts before throwing error (default: 20)
    
    .OUTPUTS
        Returns a complex password string meeting Windows complexity requirements
    
    .EXAMPLE
        New-ComplexPassword -Length 32
    
    .EXAMPLE
        $password = New-ComplexPassword -Length 64
    
    .NOTES
        Uses System.Security.Cryptography.RNGCryptoServiceProvider for secure random generation
        Only uses printable ASCII characters (33-126)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateRange(8, 256)]
        [int]$Length = 64,
        
        [Parameter()]
        [int]$MaxAttempts = 20
    )
    
    $iteration = 0
    
    do {
        if ($iteration -ge $MaxAttempts) {
            throw "Complex password generation failed after $MaxAttempts iterations"
        }
        
        $iteration++
        Write-Verbose "Password generation attempt $iteration of $MaxAttempts"
        
        # Generate random bytes
        $passwordBytes = New-Object byte[] $Length
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
        
        # Collect valid printable ASCII characters
        $validBytes = @()
        while ($validBytes.Count -lt $Length) {
            $rng.GetBytes($passwordBytes)
            foreach ($byte in $passwordBytes) {
                # Only accept printable ASCII characters (33-126)
                # Excludes control characters and extended ASCII
                if ($byte -ge 33 -and $byte -le 126) {
                    $validBytes += $byte
                    if ($validBytes.Count -eq $Length) {
                        break
                    }
                }
            }
        }
        
        # Convert bytes to password string
        $password = -join ($validBytes | ForEach-Object { [char]$_ })
        $rng.Dispose()
        
        # Test if password meets complexity requirements
        $isComplex = Test-PasswordComplexity -Password $password
        
        if ($isComplex) {
            Write-Verbose "Generated complex password of length $Length on attempt $iteration"
        }
    }
    while (-not $isComplex)
    
    return $password
}
