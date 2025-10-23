Function Invoke-ADReplication {
<#
.SYNOPSIS
    Forces replication of a single AD object from source DC to target DC.

.DESCRIPTION
    Uses the replicateSingleObject operational attribute to force immediate replication
    of a specific AD object from a source DC to a target DC. Supports both full object
    replication and secrets-only replication.
    
    This is critical after Krbtgt password resets to ensure rapid convergence across
    all domain controllers.

.PARAMETER SourceDCNTDSSettingsObjectDN
    The Distinguished Name of the NTDS Settings object of the source DC.
    Format: "CN=NTDS Settings,CN=ServerName,CN=Servers,CN=SiteName,CN=Sites,CN=Configuration,DC=domain,DC=com"

.PARAMETER TargetDCFQDN
    The FQDN of the target domain controller that should pull the replication.

.PARAMETER ObjectDN
    The Distinguished Name of the object to replicate.

.PARAMETER ContentScope
    The scope of content to replicate:
    - "Full": Replicate all attributes of the object
    - "Secrets": Replicate only secret attributes (passwords, etc.)

.PARAMETER IsLocalForest
    Boolean indicating if the target forest is the local forest ($true) or remote ($false).

.PARAMETER Credential
    Optional PSCredential for authentication to remote forests.

.OUTPUTS
    Boolean - $true if replication was triggered successfully, $false otherwise.

.EXAMPLE
    $success = Invoke-ADReplication `
        -SourceDCNTDSSettingsObjectDN "CN=NTDS Settings,CN=DC01,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=contoso,DC=com" `
        -TargetDCFQDN "dc02.contoso.com" `
        -ObjectDN "CN=krbtgt,CN=Users,DC=contoso,DC=com" `
        -ContentScope "Secrets" `
        -IsLocalForest $true
    
    Forces secrets-only replication of the krbtgt account from DC01 to DC02.

.EXAMPLE
    $creds = Get-Credential
    Invoke-ADReplication `
        -SourceDCNTDSSettingsObjectDN $ntdsSettings `
        -TargetDCFQDN "dc01.fabrikam.com" `
        -ObjectDN $objectDN `
        -ContentScope "Full" `
        -IsLocalForest $false `
        -Credential $creds
    
    Forces full object replication in a remote forest with credentials.

.NOTES
    Original function: replicateSingleADObject
    Extracted from: Reset-Krbtgt-Password-For-RWDCs-And-RODCs.ps1 (lines 3619-3717)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    Uses ADSI to manipulate the replicateSingleObject operational attribute.
    Reference: https://msdn.microsoft.com/en-us/library/cc223306.aspx
#>
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceDCNTDSSettingsObjectDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDCFQDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectDN,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Full', 'Secrets')]
        [string]$ContentScope,

        [Parameter(Mandatory = $true)]
        [bool]$IsLocalForest,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null
    )

    Process {
        Try {
            # Connect to RootDSE
            Write-Log -Message "Connecting to RootDSE on '$TargetDCFQDN'..." -Level INFO
            
            $rootDSE = $null
            if ($IsLocalForest -or (-not $Credential)) {
                $rootDSE = [ADSI]"LDAP://$TargetDCFQDN/rootDSE"
            } else {
                $rootDSE = New-Object System.DirectoryServices.DirectoryEntry(
                    "LDAP://$TargetDCFQDN/rootDSE",
                    $Credential.UserName,
                    $Credential.GetNetworkCredential().Password
                )
            }

            # Construct replication command
            $replCmd = "${SourceDCNTDSSettingsObjectDN}:${ObjectDN}"
            if ($ContentScope -eq 'Secrets') {
                $replCmd += ":SECRETS_ONLY"
            }

            Write-Log -Message "Triggering $ContentScope replication..." -Level INFO
            Write-Log -Message "  Source: $SourceDCNTDSSettingsObjectDN" -Level INFO
            Write-Log -Message "  Target: $TargetDCFQDN" -Level INFO
            Write-Log -Message "  Object: $ObjectDN" -Level INFO

            # Perform replication
            $rootDSE.Put("replicateSingleObject", $replCmd)
            $rootDSE.SetInfo()

            Write-Log -Message "Successfully triggered replication on '$TargetDCFQDN'" -Level SUCCESS
            Return $true
        }
        Catch {
            $credInfo = if ($Credential) { " using '$($Credential.UserName)'" } else { "" }
            Write-Log -Message "ERROR: Failed to trigger replication on '$TargetDCFQDN'$credInfo" -Level ERROR
            Write-Log -Message "Source: $SourceDCNTDSSettingsObjectDN" -Level ERROR
            Write-Log -Message "Object: $ObjectDN" -Level ERROR
            Write-Log -Message "Scope: $ContentScope" -Level ERROR
            Write-Log -Message "Exception Type: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "Exception Message: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Return $false
        }
    }
}
