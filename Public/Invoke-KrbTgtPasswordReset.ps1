function Invoke-KrbtgtPasswordReset {
    <#
    .SYNOPSIS
        Resets Krbtgt account passwords
    
    .DESCRIPTION
        Convenience wrapper for Reset-KrbtgtPassword that simplifies the interface.
        Supports both TEST and PRODUCTION password resets with clear parameter switches.
        
        By default, operates on TEST accounts for safe testing.
        Use -Production switch for actual production password reset (LIVE IMPACT!).
        Use -WhatIf to simulate without making changes.
    
    .PARAMETER TargetDomain
        FQDN of target Active Directory domain
    
    .PARAMETER Scope
        Scope of Krbtgt accounts to target
        Valid values: AllRWDCs, AllRODCs, SpecificRODCs
    
    .PARAMETER TargetRODCs
        Array of RODC FQDNs when Scope is SpecificRODCs
    
    .PARAMETER Production
        Reset PRODUCTION Krbtgt accounts (LIVE IMPACT!)
        If not specified, resets TEST accounts only (safe)
    
    .PARAMETER Credential
        PSCredential for authentication to remote domain
    
    .PARAMETER ContinueOnWarning
        Continue without confirmation prompts (for automated runs)
    
    .OUTPUTS
        None. Password reset results are displayed via logging output.
    
    .EXAMPLE
        Invoke-KrbtgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs
        
        Resets TEST account passwords (safe testing)
    
    .EXAMPLE
        Invoke-KrbtgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs -WhatIf
        
        Simulates TEST account password reset (no changes)
    
    .EXAMPLE
        Invoke-KrbtgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs -Production
        
        Resets PRODUCTION Krbtgt passwords (LIVE IMPACT! - requires confirmation)
    
    .EXAMPLE
        Invoke-KrbtgtPasswordReset -TargetDomain "contoso.com" -Scope AllRWDCs -Production -WhatIf
        
        Simulates PRODUCTION password reset (no changes)
    
    .EXAMPLE
        "contoso.com", "fabrikam.com" | Invoke-KrbtgtPasswordReset -Scope AllRWDCs
        
        Resets TEST accounts for multiple domains via pipeline
    
    .NOTES
        This is a convenience wrapper that calls Reset-KrbtgtPassword with appropriate mode.
        
        Modes used:
        - Default: ResetTest (reset TEST accounts)
        - -WhatIf: SimulateTest (simulate TEST reset)
        - -Production: ResetProd (reset PROD accounts) ⚠️ LIVE IMPACT
        - -Production -WhatIf: SimulateProd (simulate PROD reset)
        
        Supports standard PowerShell -WhatIf and -Confirm switches.
    
    .LINK
        Reset-KrbtgtPassword
        New-TestKrbtgtAccount
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDomain,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('AllRWDCs', 'AllRODCs', 'SpecificRODCs')]
        [string]$Scope = 'AllRWDCs',
        
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$TargetRODCs,
        
        [Parameter(Mandatory = $false)]
        [switch]$Production,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnWarning
    )
    
    begin {
        Write-Verbose 'Starting Krbtgt password reset process'
    }
    
    process {
        try {
            # Determine the mode based on parameters and -WhatIf preference
            if ($Production -and $WhatIfPreference) {
                $mode = 'SimulateProd'
                Write-Verbose 'Mode: SimulateProd (Production WhatIf)'
            }
            elseif ($Production) {
                $mode = 'ResetProd'
                Write-Verbose 'Mode: ResetProd (Production LIVE RESET)'
            }
            elseif ($WhatIfPreference) {
                $mode = 'SimulateTest'
                Write-Verbose 'Mode: SimulateTest (Test WhatIf)'
            }
            else {
                $mode = 'ResetTest'
                Write-Verbose 'Mode: ResetTest (Test account reset)'
            }
            
            Write-Verbose "Resetting Krbtgt passwords for domain: $TargetDomain with scope: $Scope"
            
            # Build parameter hashtable
            $params = @{
                Mode = $mode
                TargetDomain = $TargetDomain
                Scope = $Scope
            }
            
            if ($TargetRODCs) {
                $params['TargetRODCs'] = $TargetRODCs
                Write-Verbose "Targeting specific RODCs: $($TargetRODCs -join ', ')"
            }
            
            if ($Credential) {
                $params['Credential'] = $Credential
                Write-Verbose 'Using alternate credentials for authentication'
            }
            
            if ($ContinueOnWarning) {
                $params['ContinueOnWarning'] = $true
                Write-Verbose 'ContinueOnWarning enabled - will not prompt for confirmations'
            }
            
            # Pass through WhatIf and Confirm preferences
            if ($PSBoundParameters.ContainsKey('WhatIf')) {
                $params['WhatIf'] = $WhatIfPreference
            }
            
            if ($PSBoundParameters.ContainsKey('Confirm')) {
                $params['Confirm'] = $ConfirmPreference
            }
            
            # ShouldProcess check for high-impact operations
            $target = "$TargetDomain ($Scope)"
            $action = if ($Production) { 'Reset PRODUCTION Krbtgt passwords' } else { 'Reset TEST Krbtgt passwords' }
            
            if ($PSCmdlet.ShouldProcess($target, $action)) {
                Reset-KrbtgtPassword @params
            }
        }
        catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'KrbtgtPasswordResetFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $TargetDomain
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
    
    end {
        Write-Verbose 'Completed Krbtgt password reset process'
    }
}
