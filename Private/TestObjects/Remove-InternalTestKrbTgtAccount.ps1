Function Remove-InternalTestKrbTgtAccount {
    <#
    .SYNOPSIS
        Deletes a TEST KrbTgt account from Active Directory.

    .DESCRIPTION
        Removes a test/bogus KrbTgt account (with _TEST suffix) from Active Directory.
        Used in Mode 9 to clean up test accounts created by New-InternalTestKrbTgtAccount.
        Verifies deletion was successful.

    .PARAMETER TargetedADDomainRWDCFQDN
        The FQDN of the RWDC where the TEST account will be deleted.

    .PARAMETER KrbTgtSamAccountName
        The SamAccountName of the TEST KrbTgt account to delete (must end with _TEST).

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
        [string]$KrbTgtSamAccountName,

        [Parameter(Mandatory = $true)]
        [bool]$LocalADForest,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$AdminCredentials
    )

    # Check If The Test/Bogus KrbTgt Account Exists In AD
    $testKrbTgtObject = $null
    If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
        Try {
            $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
            $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$KrbTgtSamAccountName))"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'sAMAccountName=$KrbTgtSamAccountName'..." -Level ERROR
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
            $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$KrbTgtSamAccountName))"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object 'sAMAccountName=$KrbTgtSamAccountName'..." -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    }
    If ($testKrbTgtObject) {
        # If It Does Exist In AD
        $testKrbTgtObjectDN = $testKrbTgtObject.DistinguishedName
        Write-Log -Message "  --> RWDC To Delete Object On..............: '$TargetedADDomainRWDCFQDN'"
        Write-Log -Message "  --> Test KrbTgt Account DN................: '$testKrbTgtObjectDN'"
        Write-Log -Message ""
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                Remove-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $testKrbTgtObjectDN
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Deleting User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbTgtObjectDN'..." -Level ERROR
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
                Remove-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $testKrbTgtObjectDN
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Deleting User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbTgtObjectDN' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                Write-Log -Message "" -Level ERROR
            }
        }
        $testKrbTgtObject = $null
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbTgtObjectDN)"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'distinguishedName=$testKrbTgtObjectDN'..." -Level ERROR
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
                $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbTgtObjectDN)"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'distinguishedName=$testKrbTgtObjectDN' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                Write-Log -Message "" -Level ERROR
            }
        }
        If (!$testKrbTgtObject) {
            Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] DELETED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
        } Else {
            Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] FAILED TO BE DELETED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
            Write-Log -Message "  --> Manually delete the Test KrbTgt Account [$testKrbTgtObjectDN] on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    } Else {
        # If It Does Not Exist In AD
        Write-Log -Message "  --> Test KrbTgt Account [sAMAccountName=$KrbTgtSamAccountName] DOES NOT EXIST on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level WARNING
        Write-Log -Message "" -Level WARNING
    }
}
