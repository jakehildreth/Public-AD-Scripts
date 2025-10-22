function Test-ADReplication {
    <#
    .SYNOPSIS
        Tests Active Directory replication using a temporary canary object
    
    .DESCRIPTION
        Convenience wrapper for Reset-KrbTgtPassword -Mode SimulateCanary.
        Creates a temporary contact object and monitors its replication across domain controllers.
        
        This is useful for:
        - Verifying replication is working before KrbTgt password reset
        - Testing replication convergence time
        - Identifying replication issues
        
        The temporary object is automatically cleaned up after testing.
    
    .PARAMETER TargetDomain
        FQDN of target Active Directory domain
    
    .PARAMETER Scope
        Scope of domain controllers to test replication to
        Valid values: AllRWDCs, AllRODCs, SpecificRODCs
    
    .PARAMETER TargetRODCs
        Array of RODC FQDNs when Scope is SpecificRODCs
    
    .PARAMETER Credential
        PSCredential for authentication to remote domain
    
    .PARAMETER ContinueOnWarning
        Continue without confirmation prompts (for automated runs)
    
    .EXAMPLE
        Test-ADReplication -TargetDomain "contoso.com" -Scope AllRWDCs
        
        Tests replication to all Read-Write Domain Controllers
    
    .EXAMPLE
        Test-ADReplication -TargetDomain "contoso.com" -Scope AllRODCs
        
        Tests replication to all Read-Only Domain Controllers
    
    .EXAMPLE
        $rodcs = @("RODC1.contoso.com", "RODC2.contoso.com")
        Test-ADReplication -TargetDomain "contoso.com" -Scope SpecificRODCs -TargetRODCs $rodcs
        
        Tests replication to specific RODCs
    
    .NOTES
        This is a convenience wrapper that calls Reset-KrbTgtPassword -Mode SimulateCanary.
        A temporary canary object is created and then removed.
    
    .LINK
        Reset-KrbTgtPassword
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$TargetDomain,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('AllRWDCs', 'AllRODCs', 'SpecificRODCs')]
        [string]$Scope = 'AllRWDCs',
        
        [Parameter(Mandatory=$false)]
        [string[]]$TargetRODCs,
        
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory=$false)]
        [switch]$ContinueOnWarning
    )
    
    $params = @{
        Mode = 'SimulateCanary'
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
    
    Reset-KrbTgtPassword @params
}
