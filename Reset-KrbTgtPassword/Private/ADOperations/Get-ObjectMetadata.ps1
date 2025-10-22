Function Get-ObjectMetadata {
<#
.SYNOPSIS
    Retrieves replication metadata for an Active Directory object.

.DESCRIPTION
    Gets the replication metadata for a specified AD object from a target domain controller.
    This includes information about attribute changes such as:
    - Last originating change time
    - Originating server (RWDC)
    - Attribute version
    - Local USN
    
    This metadata is critical for tracking password resets and verifying replication.

.PARAMETER TargetDCFQDN
    The FQDN of the domain controller to query for metadata.

.PARAMETER ObjectDN
    The Distinguished Name of the object whose metadata to retrieve.

.PARAMETER IsLocalForest
    Boolean indicating if the target forest is the local forest ($true) or remote ($false).

.PARAMETER Credential
    Optional PSCredential for authentication to remote forests.

.OUTPUTS
    Collection of metadata objects, each containing:
    - Name: Attribute name
    - LastOriginatingChangeTime: When the attribute was last changed
    - LocalChangeUsn: Local USN of the change
    - OriginatingChangeUsn: Originating USN of the change
    - OriginatingServer: FQDN of the originating DC
    - Version: Version number of the attribute

.EXAMPLE
    $metadata = Get-ObjectMetadata -TargetDCFQDN "dc01.contoso.com" -ObjectDN "CN=krbtgt,CN=Users,DC=contoso,DC=com" -IsLocalForest $true
    $pwdLastSet = $metadata | Where-Object {$_.Name -eq "pwdLastSet"}
    Write-Host "Last password change: $($pwdLastSet.LastOriginatingChangeTime)"
    Write-Host "Originating DC: $($pwdLastSet.OriginatingServer)"
    
    Retrieves metadata for the KrbTgt account and displays password change info.

.EXAMPLE
    $creds = Get-Credential
    $metadata = Get-ObjectMetadata -TargetDCFQDN "dc01.fabrikam.com" -ObjectDN "CN=Test User,OU=Users,DC=fabrikam,DC=com" -IsLocalForest $false -Credential $creds
    
    Retrieves metadata for an object in a remote forest using credentials.

.NOTES
    Original function: retrieveObjectMetadata
    Extracted from: Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 (lines 3394-3429)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    Uses System.DirectoryServices.ActiveDirectory.DomainController.GetReplicationMetadata()
    to retrieve comprehensive replication metadata without requiring the ActiveDirectory module.
#>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDCFQDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectDN,

        [Parameter(Mandatory = $true)]
        [bool]$IsLocalForest,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null
    )

    Process {
        Try {
            Write-Log -Message "Retrieving replication metadata from '$TargetDCFQDN' for object '$ObjectDN'..." -Level INFO

            # Create directory context
            $dcContext = $null
            if ($IsLocalForest -or (-not $Credential)) {
                $dcContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("DirectoryServer", $TargetDCFQDN)
            } else {
                $dcContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(
                    "DirectoryServer", 
                    $TargetDCFQDN, 
                    $Credential.UserName, 
                    $Credential.GetNetworkCredential().Password
                )
            }

            # Get DC object and retrieve metadata
            $dcObject = [System.DirectoryServices.ActiveDirectory.DomainController]::GetDomainController($dcContext)
            $metadata = $dcObject.GetReplicationMetadata($ObjectDN)

            if ($metadata) {
                Write-Log -Message "Successfully retrieved metadata for object '$ObjectDN'" -Level SUCCESS
                Return $metadata.Values
            } else {
                Write-Log -Message "No metadata returned for object '$ObjectDN'" -Level WARNING
                Return $null
            }
        }
        Catch {
            $credInfo = if ($Credential) { " using '$($Credential.UserName)'" } else { "" }
            Write-Log -Message "ERROR: Failed to get metadata from '$TargetDCFQDN' for object '$ObjectDN'$credInfo" -Level ERROR
            Write-Log -Message "Exception Type: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "Exception Message: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Return $null
        }
    }
}
