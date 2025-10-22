Function Test-ADReplicationConvergence {
<#
.SYNOPSIS
    Tests if an AD object has replicated to all specified domain controllers.

.DESCRIPTION
    Checks multiple domain controllers to verify that an AD object exists and has
    the expected attribute value (typically pwdLastSet for KrbTgt accounts).
    This is used to verify that password changes have fully replicated.

.PARAMETER DomainFQDN
    The FQDN of the domain.

.PARAMETER ObjectDN
    The Distinguished Name of the object to check.

.PARAMETER DomainControllers
    Array of domain controller FQDNs to check.

.PARAMETER AttributeName
    The attribute to check (default: "pwdLastSet").

.PARAMETER ExpectedValue
    The expected value of the attribute (optional - if not specified, just checks object exists).

.PARAMETER IsLocalForest
    Boolean indicating if checking local or remote forest.

.PARAMETER Credential
    Optional PSCredential for remote forest authentication.

.PARAMETER MaxWaitMinutes
    Maximum time to wait for convergence (default: 30 minutes).

.OUTPUTS
    Hashtable with:
    - Converged: Boolean indicating if replication converged
    - ReplicatedDCs: Array of DCs where object was found/correct
    - PendingDCs: Array of DCs where object is missing/incorrect
    - TimeTaken: TimeSpan showing how long the check took

.EXAMPLE
    $result = Test-ADReplicationConvergence `
        -DomainFQDN "contoso.com" `
        -ObjectDN "CN=krbtgt,CN=Users,DC=contoso,DC=com" `
        -DomainControllers @("dc01.contoso.com", "dc02.contoso.com") `
        -AttributeName "pwdLastSet" `
        -IsLocalForest $true

.NOTES
    Version: 4.0.0
    Polls DCs at intervals to check replication status.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$DomainFQDN,

        [Parameter(Mandatory = $true)]
        [string]$ObjectDN,

        [Parameter(Mandatory = $true)]
        [string[]]$DomainControllers,

        [Parameter(Mandatory = $false)]
        [string]$AttributeName = "pwdLastSet",

        [Parameter(Mandatory = $false)]
        $ExpectedValue = $null,

        [Parameter(Mandatory = $true)]
        [bool]$IsLocalForest,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null,

        [Parameter(Mandatory = $false)]
        [int]$MaxWaitMinutes = 30
    )

    Process {
        $startTime = Get-Date
        $timeout = $startTime.AddMinutes($MaxWaitMinutes)
        
        $result = @{
            Converged = $false
            ReplicatedDCs = @()
            PendingDCs = @()
            TimeTaken = [TimeSpan]::Zero
        }

        Write-Log -Message "Checking replication convergence for object: $ObjectDN" -Level INFO
        Write-Log -Message "Checking $($DomainControllers.Count) domain controller(s)..." -Level INFO

        $pollInterval = 5  # seconds between checks

        do {
            $replicatedDCs = @()
            $pendingDCs = @()

            foreach ($dc in $DomainControllers) {
                Try {
                    # Get LDAP connection
                    $ldapParams = @{
                        LdapServer = $dc
                        EncryptionType = 'Kerberos'
                    }
                    if ($Credential) {
                        $ldapParams['Credential'] = $Credential
                    }
                    $ldapConn = Get-LdapConnection @ldapParams

                    # Query for object
                    $obj = Find-LdapObject -LdapConnection $ldapConn `
                        -searchFilter "(distinguishedName=$ObjectDN)" `
                        -searchScope Base `
                        -PropertiesToLoad @($AttributeName)

                    if ($obj) {
                        # Object found - check value if specified
                        if ($null -eq $ExpectedValue) {
                            # Just checking existence
                            $replicatedDCs += $dc
                        } else {
                            # Check attribute value
                            $actualValue = $obj.$AttributeName
                            if ($actualValue -eq $ExpectedValue) {
                                $replicatedDCs += $dc
                            } else {
                                $pendingDCs += $dc
                            }
                        }
                    } else {
                        # Object not found yet
                        $pendingDCs += $dc
                    }
                }
                Catch {
                    Write-Log -Message "WARNING: Failed to query DC '$dc': $($_.Exception.Message)" -Level WARNING
                    $pendingDCs += $dc
                }
            }

            # Update result
            $result.ReplicatedDCs = $replicatedDCs
            $result.PendingDCs = $pendingDCs

            # Check if converged
            if ($pendingDCs.Count -eq 0) {
                $result.Converged = $true
                $result.TimeTaken = (Get-Date) - $startTime
                Write-Log -Message "Replication converged! All DCs have the object." -Level SUCCESS
                Write-Log -Message "Time taken: $($result.TimeTaken.TotalSeconds) seconds" -Level SUCCESS
                Return $result
            }

            # Log progress
            Write-Log -Message "Replicated to $($replicatedDCs.Count)/$($DomainControllers.Count) DCs. Waiting..." -Level INFO
            
            # Wait before next check (unless timed out)
            if ((Get-Date) -lt $timeout) {
                Start-Sleep -Seconds $pollInterval
            }

        } while ((Get-Date) -lt $timeout)

        # Timeout reached
        $result.Converged = $false
        $result.TimeTaken = (Get-Date) - $startTime
        Write-Log -Message "WARNING: Replication did not fully converge within $MaxWaitMinutes minutes" -Level WARNING
        Write-Log -Message "Replicated to $($replicatedDCs.Count)/$($DomainControllers.Count) DCs" -Level WARNING
        Write-Log -Message "Pending DCs: $($pendingDCs -join ', ')" -Level WARNING

        Return $result
    }
}
