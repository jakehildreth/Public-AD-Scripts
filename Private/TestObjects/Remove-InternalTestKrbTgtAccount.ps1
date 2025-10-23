Function Remove-InternalTestKrbtgtAccount {
    <#
    .SYNOPSIS
        Deletes a TEST Krbtgt account from Active Directory.

    .DESCRIPTION
        Removes a test/bogus Krbtgt account (with _TEST suffix) from Active Directory.
        Used in Mode 9 to clean up test accounts created by New-InternalTestKrbtgtAccount.
        Verifies deletion was successful.

    .PARAMETER TargetedADDomainRWDCFQDN
        The FQDN of the RWDC where the TEST account will be deleted.

    .PARAMETER KrbtgtSamAccountName
        The SamAccountName of the TEST Krbtgt account to delete (must end with _TEST).

    .PARAMETER LocalADForest
        Boolean indicating whether the target domain is in the local forest.

    .PARAMETER AdminCredentials
        [PSCredential] Optional credentials for accessing remote forests.

    .OUTPUTS
        None. Logs deletion status via Write-Log.

    .NOTES
        Author: Original function from Reset-Krbtgt-Password-For-RWDCs-And-RODCs.ps1 v3.4
        Modified: Extracted to modular structure for Reset-KrbtgtPassword v4.0.0
        Dependencies: Get-LdapConnection, Get-RootDSE, Remove-LdapObject, Find-LdapObject, Write-Log
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$TargetedADDomainRWDCFQDN,

        [Parameter(Mandatory = $true)]
        [string]$KrbtgtSamAccountName,

        [Parameter(Mandatory = $true)]
        [bool]$LocalADForest,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$AdminCredentials
    )

    # Check If The Test/Bogus Krbtgt Account Exists In AD
    $testKrbtgtObject = $null
    If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
        Try {
            $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
            $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$KrbtgtSamAccountName))"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'sAMAccountName=$KrbtgtSamAccountName'..." -Level ERROR
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
            $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$KrbtgtSamAccountName))"
        } Catch {
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object 'sAMAccountName=$KrbtgtSamAccountName'..." -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "" -Level ERROR
            Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    }
    If ($testKrbtgtObject) {
        # If It Does Exist In AD
        $testKrbtgtObjectDN = $testKrbtgtObject.DistinguishedName
        Write-Log -Message "  --> RWDC To Delete Object On..............: '$TargetedADDomainRWDCFQDN'"
        Write-Log -Message "  --> Test Krbtgt Account DN................: '$testKrbtgtObjectDN'"
        Write-Log -Message ""
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                Remove-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $testKrbtgtObjectDN
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Deleting User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbtgtObjectDN'..." -Level ERROR
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
                Remove-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $testKrbtgtObjectDN
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Deleting User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbtgtObjectDN' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                Write-Log -Message "" -Level ERROR
            }
        }
        $testKrbtgtObject = $null
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbtgtObjectDN)"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'distinguishedName=$testKrbtgtObjectDN'..." -Level ERROR
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
                $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbtgtObjectDN)"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'distinguishedName=$testKrbtgtObjectDN' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                Write-Log -Message "" -Level ERROR
            }
        }
        If (!$testKrbtgtObject) {
            Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] DELETED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
        } Else {
            Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] FAILED TO BE DELETED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
            Write-Log -Message "  --> Manually delete the Test Krbtgt Account [$testKrbtgtObjectDN] on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
            Write-Log -Message "" -Level ERROR
        }
    } Else {
        # If It Does Not Exist In AD
        Write-Log -Message "  --> Test Krbtgt Account [sAMAccountName=$KrbtgtSamAccountName] DOES NOT EXIST on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level WARNING
        Write-Log -Message "" -Level WARNING
    }
}
