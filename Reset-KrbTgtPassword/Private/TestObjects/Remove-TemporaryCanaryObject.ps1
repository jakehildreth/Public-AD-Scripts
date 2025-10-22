Function Remove-TemporaryCanaryObject {
    <#
    .SYNOPSIS
        Deletes a temporary canary object from Active Directory.

    .DESCRIPTION
        Removes the temporary contact object created by New-TemporaryCanaryObject after replication
        testing is complete. Verifies deletion was successful by querying for the object.

    .PARAMETER TargetedADDomainRWDCFQDN
        The FQDN of the RWDC where the canary object will be deleted.

    .PARAMETER TargetObjectToCheckDN
        The DistinguishedName of the canary object to delete.

    .PARAMETER LocalADForest
        Boolean indicating whether the target domain is in the local forest.

    .PARAMETER AdminCredentials
        [PSCredential] Optional credentials for accessing remote forests.

    .OUTPUTS
        None. Logs deletion status via Write-Log.

    .NOTES
        Author: Original function from Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 v3.4
        Modified: Extracted to modular structure for Reset-KrbTgtPassword v4.0.0
        Dependencies: Get-LdapConnection, Get-RootDSE, Remove-LdapObject, Find-LdapObject, Write-Log
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$TargetedADDomainRWDCFQDN,

        [Parameter(Mandatory = $true)]
        [string]$TargetObjectToCheckDN,

        [Parameter(Mandatory = $true)]
        [bool]$LocalADForest,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$AdminCredentials
    )

    # Try To Delete The Canary Object In The AD Domain And If Not Successfull Throw Error
    Try {
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Remove-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $TargetObjectToCheckDN
        }
        If ($LocalADForest -eq $false -And $AdminCredentials) {
            Remove-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $TargetObjectToCheckDN
        }
    } Catch {
        Write-Log -Message "  --> Temp Canary Object [$TargetObjectToCheckDN] FAILED TO BE DELETED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
        Write-Log -Message "  --> Manually delete the Temp Canary Object [$TargetObjectToCheckDN] on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
        Write-Log -Message "" -Level ERROR
        Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
        Write-Log -Message "" -Level ERROR
        Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
        Write-Log -Message "" -Level ERROR
        Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
        Write-Log -Message "" -Level ERROR
    }

    # Retrieve The Temporary Canary Object From The AD Domain And If It Does Not Exist It Was Deleted Successfully
    $targetObjectToCheck = $null
    If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
        Try {
            $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
            $targetObjectToCheck = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$TargetObjectToCheckDN)"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'distinguishedName=$TargetObjectToCheckDN'..." -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    }
    If ($LocalADForest -eq $false -And $AdminCredentials) {
        Try {
            $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials)).defaultNamingContext.distinguishedName
            $targetObjectToCheck = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$TargetObjectToCheckDN)"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'distinguishedName=$TargetObjectToCheckDN' Using '$($AdminCredentials.UserName)'..." -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    }
    If (!$targetObjectToCheck) {
        Write-Log -Message "  --> Temp Canary Object [$TargetObjectToCheckDN] DELETED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
        Write-Log -Message "" -Level REMARK
    }
}
