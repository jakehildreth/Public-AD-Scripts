Function New-TemporaryCanaryObject {
    <#
    .SYNOPSIS
        Creates a temporary contact object for AD replication testing.

    .DESCRIPTION
        Creates a temporary canary object (contact) in the CN=Users container to test AD replication
        convergence. The object name includes timestamp and KrbTgt account name for uniqueness.
        Used to verify replication works before performing actual KrbTgt password reset operations.

    .PARAMETER TargetedADDomainRWDCFQDN
        The FQDN of the RWDC where the canary object will be created.

    .PARAMETER KrbTgtSamAccountName
        The SamAccountName of the KrbTgt account (used to generate unique canary object name).

    .PARAMETER ExecDateTimeCustom
        Timestamp string to ensure unique canary object names.

    .PARAMETER LocalADForest
        Boolean indicating whether the target domain is in the local forest.

    .PARAMETER AdminCredentials
        [PSCredential] Optional credentials for accessing remote forests.

    .OUTPUTS
        System.String - Returns the DistinguishedName of the created canary object, or $null if creation failed.

    .NOTES
        Author: Original function from Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 v3.4
        Modified: Extracted to modular structure for Reset-KrbTgtPassword v4.0.0
        Dependencies: Get-LdapConnection, Get-RootDSE, Add-LdapObject, Find-LdapObject, Write-Log
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$TargetedADDomainRWDCFQDN,

        [Parameter(Mandatory = $true)]
        [string]$KrbTgtSamAccountName,

        [Parameter(Mandatory = $true)]
        [string]$ExecDateTimeCustom,

        [Parameter(Mandatory = $true)]
        [bool]$LocalADForest,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$AdminCredentials
    )

    # Determine The DN Of The Default NC Of The Targeted Domain
    $targetedADdomainDefaultNC = $null
    If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
        Try {
            $targetedADdomainDefaultNC = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Connecting To '$TargetedADDomainRWDCFQDN' For 'rootDSE'..." -Level ERROR
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
            $targetedADdomainDefaultNC = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials)).defaultNamingContext.distinguishedName
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Connecting To '$TargetedADDomainRWDCFQDN' For 'rootDSE' Using '$($AdminCredentials.UserName)'..." -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    }

    # Determine The DN Of The Users Container Of The Targeted Domain
    $containerForTempCanaryObject = $null
    $containerForTempCanaryObject = "CN=Users," + $targetedADdomainDefaultNC

    # Generate The Name Of The Temporary Canary Object
    $targetObjectToCheckName = $null
    $targetObjectToCheckName = "_adReplTempObject_" + $KrbTgtSamAccountName + "_" + $ExecDateTimeCustom

    # Specify The Description Of The Temporary Canary Object
    $targetObjectToCheckDescription = "...!!!.TEMP OBJECT TO CHECK AD REPLICATION IMPACT.!!!..."

    # Generate The DN Of The Temporary Canary Object
    $targetObjectToCheckDN = $null
    $targetObjectToCheckDN = "CN=" + $targetObjectToCheckName + "," + $containerForTempCanaryObject
    Write-Log -Message "  --> RWDC To Create Object On..............: '$TargetedADDomainRWDCFQDN'"
    Write-Log -Message "  --> Full Name Temp Canary Object..........: '$targetObjectToCheckName'"
    Write-Log -Message "  --> Description...........................: '$targetObjectToCheckDescription'"
    Write-Log -Message "  --> Container For Temp Canary Object......: '$containerForTempCanaryObject'"
    Write-Log -Message ""

    # Try To Create The Canary Object In The AD Domain And If Not Successfull Throw Error
    Try {
        $contactObject = [PSCustomObject]@{
            distinguishedName = "CN=$targetObjectToCheckName,$containerForTempCanaryObject"
            objectClass       = "contact"
            displayName       = $targetObjectToCheckName
            description       = $targetObjectToCheckDescription
        }
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Add-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $contactObject
        }
        If ($LocalADForest -eq $false -And $AdminCredentials) {
            Add-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $contactObject
        }
    } Catch {
        Write-Log -Message "  --> Temp Canary Object [$targetObjectToCheckDN] FAILED TO BE CREATED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
        Write-Log -Message "" -Level ERROR
        Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
        Write-Log -Message "" -Level ERROR
        Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
        Write-Log -Message "" -Level ERROR
        Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
        Write-Log -Message "" -Level ERROR
    }

    # Check The Temporary Canary Object Exists And Was created In AD
    $targetObjectToCheck = $null
    If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
        Try {
            $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
            $targetObjectToCheck = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectClass=contact)(name=$targetObjectToCheckName))"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For Contact Object With 'name=$targetObjectToCheckName'..." -Level ERROR
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
            $targetObjectToCheck = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectClass=contact)(name=$targetObjectToCheckName))"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For Contact Object With 'name=$targetObjectToCheckName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    }
    If ($targetObjectToCheck) {
        $targetObjectToCheckDN = $targetObjectToCheck.DistinguishedName
        Write-Log -Message "  --> Temp Canary Object [$targetObjectToCheckDN] CREATED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
        Write-Log -Message "" -Level REMARK
    }
    Return $targetObjectToCheckDN
}
