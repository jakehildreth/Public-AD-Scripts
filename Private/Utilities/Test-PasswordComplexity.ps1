function Test-PasswordComplexity {
    <#
    .SYNOPSIS
        Validates password meets Windows complexity requirements
    
    .DESCRIPTION
        Checks if a password meets Windows password complexity requirements:
        - At least 8 characters long
        - Contains characters from at least 3 of these categories:
          * Uppercase letters (A-Z)
          * Lowercase letters (a-z)
          * Numbers (0-9)
          * Special characters (non-alphanumeric)
        
        This function replaces the 'confirmPasswordIsComplex' function from the original script.
    
    .PARAMETER Password
        The password string to validate
    
    .OUTPUTS
        Returns $true if password meets complexity requirements, $false otherwise
    
    .EXAMPLE
        Test-PasswordComplexity -Password "P@ssw0rd123"
    
    .EXAMPLE
        if (Test-PasswordComplexity -Password $pwd) {
            Write-Host "Password is complex"
        }
    
    .NOTES
        Implements standard Windows password complexity requirements
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    
    # Minimum length check
    if ($Password.Length -lt 8) {
        Write-Verbose "Password does not meet minimum length requirement (8 characters)"
        return $false
    }
    
    $criteriaMet = 0
    
    # Check for uppercase letters (A-Z)
    if ($Password -cmatch '[A-Z]') {
        $criteriaMet++
        Write-Verbose "Password contains uppercase letters"
    }
    
    # Check for lowercase letters (a-z)
    if ($Password -cmatch '[a-z]') {
        $criteriaMet++
        Write-Verbose "Password contains lowercase letters"
    }
    
    # Check for digits (0-9)
    if ($Password -match '\d') {
        $criteriaMet++
        Write-Verbose "Password contains digits"
    }
    
    # Check for special characters (non-alphanumeric)
    if ($Password -match '[\^~!@#$%^&*_+=`|\\(){}\[\]:;"''<>,.?/]') {
        $criteriaMet++
        Write-Verbose "Password contains special characters"
    }
    
    # Must meet at least 3 of the 4 criteria
    if ($criteriaMet -ge 3) {
        Write-Verbose "Password meets complexity requirements ($criteriaMet of 4 criteria met)"
        return $true
    }
    else {
        Write-Verbose "Password does not meet complexity requirements (only $criteriaMet of 4 criteria met, need 3)"
        return $false
    }
}
