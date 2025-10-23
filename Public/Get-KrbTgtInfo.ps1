function Get-KrbtgtInfo {
    <#
    .SYNOPSIS
        Retrieves information about Krbtgt accounts and domain controllers
    
    .DESCRIPTION
        Convenience wrapper for Reset-KrbtgtPassword -Mode Info.
        Gathers information about domain controllers and Krbtgt accounts without making any changes.
        
        This is a read-only operation that displays:
        - Domain controller information (RWDCs and RODCs)
        - PDC FSMO holder
        - Krbtgt account details
        - Password last set dates
        - Domain functional level
    
    .PARAMETER TargetDomain
        FQDN of target Active Directory domain
    
    .PARAMETER Credential
        PSCredential for authentication to remote domain
    
    .OUTPUTS
        None. Information is displayed via logging output.
    
    .EXAMPLE
        Get-KrbtgtInfo -TargetDomain "contoso.com"
        
        Retrieves Krbtgt information for the contoso.com domain
    
    .EXAMPLE
        $cred = Get-Credential
        Get-KrbtgtInfo -TargetDomain "remote.fabrikam.com" -Credential $cred
        
        Retrieves Krbtgt information for a remote domain using alternate credentials
    
    .EXAMPLE
        "contoso.com", "fabrikam.com" | Get-KrbtgtInfo
        
        Retrieves Krbtgt information for multiple domains via pipeline
    
    .NOTES
        This is a convenience wrapper that calls Reset-KrbtgtPassword -Mode Info.
        No changes are made to the environment.
    
    .LINK
        Reset-KrbtgtPassword
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDomain,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    begin {
        Write-Verbose 'Starting Krbtgt information retrieval process'
    }
    
    process {
        try {
            Write-Verbose "Retrieving Krbtgt information for domain: $TargetDomain"
            
            $params = @{
                Mode = 'Info'
                TargetDomain = $TargetDomain
            }
            
            if ($Credential) {
                $params['Credential'] = $Credential
                Write-Verbose 'Using alternate credentials for authentication'
            }
            
            Reset-KrbtgtPassword @params
        }
        catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'KrbtgtInfoRetrievalFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $TargetDomain
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
    
    end {
        Write-Verbose 'Completed Krbtgt information retrieval process'
    }
}
