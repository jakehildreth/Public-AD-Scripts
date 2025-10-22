function Invoke-KrbTgtPasswordReset {
    <#
    .SYNOPSIS
        Resets KrbTgt account passwords
    
    .DESCRIPTION
        Convenience wrapper for Reset-KrbTgtPassword that simplifies the interface.
        Supports both TEST and PRODUCTION password resets with clear parameter switches.
        
        By default, operates on TEST accounts for safe testing.
        Use -Production switch for actual production password reset (LIVE IMPACT!).
        Use -WhatIf to simulate without making changes.
    
    .PARAMETER TargetDomain
        FQDN of target Active Directory domain
    
    .PARAMETER Scope
        Scope of KrbTgt accounts to target
        Valid values: AllRWDCs, AllRODCs, SpecificRODCs
    
    .PARAMETER TargetRODCs
        Array of RODC FQDNs when Scope is SpecificRODCs
    
    .PARAMETER Production
        Reset PRODUCTION KrbTgt accounts (LIVE IMPACT!)
        If not specified, resets TEST accounts only (safe)
    
    .PARAMETER Credential
        PSCredential for authentication to remote domain
    
    .PARAMETER ContinueOnWarning
        Continue without confirmation prompts (for automated runs)
    
    .EXAMPLE
        Invoke-KrbTgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs
        
        Resets TEST account passwords (safe testing)
    
    .EXAMPLE
        Invoke-KrbTgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs -WhatIf
        
        Simulates TEST account password reset (no changes)
    
    .EXAMPLE
        Invoke-KrbTgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs -Production
        
        Resets PRODUCTION KrbTgt passwords (LIVE IMPACT! - requires confirmation)
    
    .EXAMPLE
        Invoke-KrbTgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs -Production -WhatIf
        
        Simulates PRODUCTION password reset (no changes)
    
    .NOTES
        This is a convenience wrapper that calls Reset-KrbTgtPassword with appropriate mode.
        
        Modes used:
        - Default: ResetTest (reset TEST accounts)
        - -WhatIf: SimulateTest (simulate TEST reset)
        - -Production: ResetProd (reset PROD accounts) ⚠️ LIVE IMPACT
        - -Production -WhatIf: SimulateProd (simulate PROD reset)
        
        Supports standard PowerShell -WhatIf and -Confirm switches.
    
    .LINK
        Reset-KrbTgtPassword
        New-TestKrbTgtAccount
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$TargetDomain,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('AllRWDCs', 'AllRODCs', 'SpecificRODCs')]
        [string]$Scope = 'AllRWDCs',
        
        [Parameter(Mandatory=$false)]
        [string[]]$TargetRODCs,
        
        [Parameter(Mandatory=$false)]
        [switch]$Production,
        
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory=$false)]
        [switch]$ContinueOnWarning
    )
    
    # Determine the mode based on parameters and -WhatIf preference
    if ($Production -and $WhatIfPreference) {
        $mode = 'SimulateProd'
    }
    elseif ($Production) {
        $mode = 'ResetProd'
    }
    elseif ($WhatIfPreference) {
        $mode = 'SimulateTest'
    }
    else {
        $mode = 'ResetTest'
    }
    
    # Build parameter hashtable
    $params = @{
        Mode = $mode
        TargetDomain = $TargetDomain
        Scope = $Scope
    }
    
    if ($TargetRODCs) {
        $params['TargetRODCs'] = $TargetRODCs
    }
    
    if ($Credential) {
        $params['Credential'] = $Credential
    }
    
    if ($ContinueOnWarning) {
        $params['ContinueOnWarning'] = $true
    }
    
    # Pass through WhatIf and Confirm preferences
    if ($PSBoundParameters.ContainsKey('WhatIf')) {
        $params['WhatIf'] = $WhatIfPreference
    }
    
    if ($PSBoundParameters.ContainsKey('Confirm')) {
        $params['Confirm'] = $ConfirmPreference
    }
    
    Reset-KrbTgtPassword @params
}
