function Get-KrbTgtInfo {
    <#
    .SYNOPSIS
        Retrieves information about KrbTgt accounts and domain controllers
    
    .DESCRIPTION
        Convenience wrapper for Reset-KrbTgtPassword -Mode Info.
        Gathers information about domain controllers and KrbTgt accounts without making any changes.
        
        This is a read-only operation that displays:
        - Domain controller information (RWDCs and RODCs)
        - PDC FSMO holder
        - KrbTgt account details
        - Password last set dates
        - Domain functional level
    
    .PARAMETER TargetDomain
        FQDN of target Active Directory domain
    
    .PARAMETER Credential
        PSCredential for authentication to remote domain
    
    .EXAMPLE
        Get-KrbTgtInfo -TargetDomain "contoso.com"
        
        Retrieves KrbTgt information for the contoso.com domain
    
    .EXAMPLE
        $cred = Get-Credential
        Get-KrbTgtInfo -TargetDomain "remote.fabrikam.com" -Credential $cred
        
        Retrieves KrbTgt information for a remote domain using alternate credentials
    
    .NOTES
        This is a convenience wrapper that calls Reset-KrbTgtPassword -Mode Info.
        No changes are made to the environment.
    
    .LINK
        Reset-KrbTgtPassword
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$TargetDomain,
        
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )
    
    $params = @{
        Mode = 'Info'
        TargetDomain = $TargetDomain
    }
    
    if ($Credential) {
        $params['Credential'] = $Credential
    }
    
    Reset-KrbTgtPassword @params
}
