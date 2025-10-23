function Test-ADReplication {
    <#
    .SYNOPSIS
        Tests Active Directory replication using a temporary canary object
    
    .DESCRIPTION
        Convenience wrapper for Reset-KrbtgtPassword -Mode SimulateCanary.
        Creates a temporary contact object and monitors its replication across domain controllers.
        
        This is useful for:
        - Verifying replication is working before Krbtgt password reset
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
    
    .OUTPUTS
        None. Replication test results are displayed via logging output.
    
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
    
    .EXAMPLE
        "contoso.com", "fabrikam.com" | Test-ADReplication -Scope AllRWDCs
        
        Tests replication for multiple domains via pipeline
    
    .NOTES
        This is a convenience wrapper that calls Reset-KrbtgtPassword -Mode SimulateCanary.
        A temporary canary object is created and then removed.
    
    .LINK
        Reset-KrbtgtPassword
    #>
    [CmdletBinding()]
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
        [PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnWarning
    )
    
    begin {
        Write-Verbose 'Starting Active Directory replication test process'
    }
    
    process {
        try {
            Write-Verbose "Testing AD replication for domain: $TargetDomain with scope: $Scope"
            
            $params = @{
                Mode = 'SimulateCanary'
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
            
            Reset-KrbtgtPassword @params
        }
        catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'ADReplicationTestFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $TargetDomain
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
    
    end {
        Write-Verbose 'Completed Active Directory replication test process'
    }
}
