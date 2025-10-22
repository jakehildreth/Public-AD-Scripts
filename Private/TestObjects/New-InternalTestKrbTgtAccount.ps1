Function New-InternalTestKrbTgtAccount {
    <#
    .SYNOPSIS
        Creates or updates a TEST KrbTgt account in Active Directory.

    .DESCRIPTION
        Creates a test/bogus KrbTgt account (krbtgt_TEST or krbtgt_<Number>_TEST for RODCs) for
        testing purposes. For RWDC accounts, adds to Denied RODC Password Replication Group.
        For RODC accounts, adds to Allowed RODC Password Replication Group.
        If the account already exists, updates description and group membership as needed.

    .PARAMETER TargetedADDomainRWDCFQDN
        The FQDN of the RWDC where the TEST account will be created/updated.

    .PARAMETER KrbTgtInUseByDCFQDN
        For RODC accounts, the FQDN of the RODC that uses this KrbTgt account.

    .PARAMETER KrbTgtSamAccountName
        The SamAccountName for the TEST KrbTgt account (e.g., "krbtgt_TEST" or "krbtgt_12345_TEST").

    .PARAMETER KrbTgtUse
        String indicating account type: "RWDC" or "RODC".

    .PARAMETER TargetedADDomainDomainSID
        The domain SID used to build RID-based group SIDs.

    .PARAMETER LocalADForest
        Boolean indicating whether the target domain is in the local forest.

    .PARAMETER AdminCredentials
        [PSCredential] Optional credentials for accessing remote forests.

    .OUTPUTS
        None. Logs creation/update status via Write-Log.

    .NOTES
        Author: Original function from Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 v3.4
        Modified: Extracted to modular structure for Reset-KrbTgtPassword v4.0.0
        Dependencies: Get-LdapConnection, Get-RootDSE, Add-LdapObject, Edit-LdapObject, 
                      Find-LdapObject, New-ComplexPassword, Write-Log
        
        Group RIDs:
        - 571: Allowed RODC Password Replication Group (for RODC TEST accounts)
        - 572: Denied RODC Password Replication Group (for RWDC TEST accounts)
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$TargetedADDomainRWDCFQDN,

        [Parameter(Mandatory = $false)]
        [string]$KrbTgtInUseByDCFQDN,

        [Parameter(Mandatory = $true)]
        [string]$KrbTgtSamAccountName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("RWDC", "RODC")]
        [string]$KrbTgtUse,

        [Parameter(Mandatory = $true)]
        [string]$TargetedADDomainDomainSID,

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
    $containerForTestKrbTgtAccount = "CN=Users," + $targetedADdomainDefaultNC

    # Set The SamAccountName For The Test/Bogus KrbTgt Account
    $testKrbTgtObjectSamAccountName = $KrbTgtSamAccountName

    # Set The Name For The Test/Bogus KrbTgt Account
    $testKrbTgtObjectName = $testKrbTgtObjectSamAccountName

    # Set The Description For The Test/Bogus KrbTgt Account
    $testKrbTgtObjectDescription = $null

    # Set The Description For The Test/Bogus KrbTgt Account For RWDCs
    If ($KrbTgtUse -eq "RWDC") {
        $testKrbTgtObjectDescription = "Test Copy Representing '$($KrbTgtSamAccountName.SubString(0,$KrbTgtSamAccountName.IndexOf('_TEST')))' - Key Distribution Center Service Account For RWDCs"
    }

    # Set The Description For The Test/Bogus KrbTgt Account For RODCs
    If ($KrbTgtUse -eq "RODC") {
        $testKrbTgtObjectDescription = "Test Copy Representing '$($KrbTgtSamAccountName.SubString(0,$KrbTgtSamAccountName.IndexOf('_TEST')))' - Key Distribution Center Service Account For RODC '$KrbTgtInUseByDCFQDN'"
    }

    # Generate The DN Of The Test KrbTgt Object
    $testKrbTgtObjectDN = "CN=" + $testKrbTgtObjectName + "," + $containerForTestKrbTgtAccount

    # Display Information About The Test KrbTgt To Be Created/Edited
    Write-Log -Message "  --> RWDC To Create/Update Object On.......: '$TargetedADDomainRWDCFQDN'"
    Write-Log -Message "  --> Full Name Test KrbTgt Account.........: '$testKrbTgtObjectName'"
    Write-Log -Message "  --> Description...........................: '$testKrbTgtObjectDescription'"
    Write-Log -Message "  --> Container Test KrbTgt Account.........: '$containerForTestKrbTgtAccount'"
    If ($KrbTgtUse -eq "RWDC") {
        Write-Log -Message "  --> To Be Used By DC(s)...................: 'All RWDCs'"
    }
    If ($KrbTgtUse -eq "RODC") {
        Write-Log -Message "  --> To Be Used By RODC....................: '$KrbTgtInUseByDCFQDN'"
    }

    # If The Test/Bogus KrbTgt Account Is Used By RWDCs
    $deniedRODCPwdReplGroupObjectDN = $null
    $deniedRODCPwdReplGroupObjectName = $null
    If ($KrbTgtUse -eq "RWDC") {
        $deniedRODCPwdReplGroupRID = "572"
        $deniedRODCPwdReplGroupObjectSID = $TargetedADDomainDomainSID + "-" + $deniedRODCPwdReplGroupRID
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                $deniedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(objectSID=$deniedRODCPwdReplGroupObjectSID)" -PropertiesToLoad @("name")
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For Group Object With 'objectSID=$deniedRODCPwdReplGroupObjectSID'..." -Level ERROR
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
                $deniedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(objectSID=$deniedRODCPwdReplGroupObjectSID)" -PropertiesToLoad @("name")
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For Group Object With 'objectSID=$deniedRODCPwdReplGroupObjectSID' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                Write-Log -Message "" -Level ERROR
            }
        }
        $deniedRODCPwdReplGroupObjectDN = $deniedRODCPwdReplGroupObject.distinguishedName
        $deniedRODCPwdReplGroupObjectName = $deniedRODCPwdReplGroupObject.name
        Write-Log -Message "  --> Membership Of RODC PRP Group..........: '$deniedRODCPwdReplGroupObjectName' ('$deniedRODCPwdReplGroupObjectDN')"
    }

    # If The Test/Bogus KrbTgt Account Is Used By RODCs
    $allowedRODCPwdReplGroupObjectDN = $null
    $allowedRODCPwdReplGroupObjectName = $null
    If ($KrbTgtUse -eq "RODC") {
        $allowedRODCPwdReplGroupRID = "571"
        $allowedRODCPwdReplGroupObjectSID = $TargetedADDomainDomainSID + "-" + $allowedRODCPwdReplGroupRID
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                $allowedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(objectSID=$allowedRODCPwdReplGroupObjectSID)" -PropertiesToLoad @("name")
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For Group Object With 'objectSID=$allowedRODCPwdReplGroupObjectSIDD'..." -Level ERROR
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
                $allowedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(objectSID=$allowedRODCPwdReplGroupObjectSID)" -PropertiesToLoad @("name")
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For Group Object With 'objectSID=$allowedRODCPwdReplGroupObjectSID' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                Write-Log -Message "" -Level ERROR
            }
        }
        $allowedRODCPwdReplGroupObjectDN = $allowedRODCPwdReplGroupObject.distinguishedName
        $allowedRODCPwdReplGroupObjectName = $allowedRODCPwdReplGroupObject.name
        Write-Log -Message "  --> Membership Of RODC PRP Group..........: '$allowedRODCPwdReplGroupObjectName' ('$allowedRODCPwdReplGroupObjectDN')"
    }
    Write-Log -Message ""

    # Check If The Test/Bogus KrbTgt Account Already Exists In AD
    $testKrbTgtObject = $null
    If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
        Try {
            $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
            $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbTgtObjectDN)" -PropertiesToLoad @("description")
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
            $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbTgtObjectDN)" -PropertiesToLoad @("description")
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

    $updateMembership = $false
    If ($testKrbTgtObject) {
        Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] ALREADY EXISTS on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
        Write-Log -Message "" -Level REMARK

        # Update The Description For The Test KrbTgt Account If There Is A Mismatch For Whatever Reason
        If ($testKrbTgtObject.Description -ne $testKrbTgtObjectDescription) {
            $testKrbTgtObj = [PSCustomObject]@{
                distinguishedName = $testKrbTgtObjectDN
                description       = $testKrbTgtObjectDescription
            }
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Mode Replace -Object $testKrbTgtObj
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Updating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbTgtObjectSamAccountName'..." -Level ERROR
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
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Mode Replace -Object $testKrbTgtObj
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Updating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbTgtObjectSamAccountName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                }
            }
            Write-Log -Message "  --> Updated Description For Existing Test KrbTgt Account [$testKrbTgtObjectDN] on RWDC [$TargetedADDomainRWDCFQDN] Due To Mismatch!..." -Level REMARK
        }

        # Check The Membership Of The Test KrbTgt Accounts And Update As Needed
        If ($KrbTgtUse -eq "RWDC") {
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbTgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$deniedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbTgtObjectSamAccountName' For Object '$deniedRODCPwdReplGroupObjectName'..." -Level ERROR
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
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbTgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$deniedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbTgtObjectSamAccountName' For Object '$deniedRODCPwdReplGroupObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                }
            }
        }
        If ($KrbTgtUse -eq "RODC") {
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbTgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$allowedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbTgtObjectSamAccountName' For Object '$allowedRODCPwdReplGroupObjectName'..." -Level ERROR
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
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbTgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$allowedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbTgtObjectSamAccountName' For Object '$allowedRODCPwdReplGroupObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                }
            }
        }
    } Else {
        # If The Test/Bogus KrbTgt Account Does Not Exist Yet In AD
        # Specify The Number Of Characters The Generate Password Should Contain
        $passwdNrChars = 64

        # Generate A New Password With The Specified Length (Text)
        $krbTgtPassword = $null
        $krbTgtPassword = (New-ComplexPassword -Length $passwdNrChars).ToString()

        # Try To Create The Test/Bogus KrbTgt Account In The AD Domain And If Not Successfull Throw Error
        Try {
            $testKrbTgtObj = [PSCustomObject]@{
                distinguishedName  = $testKrbTgtObjectDN
                objectClass        = "user"
                sAMAccountName     = $testKrbTgtObjectSamAccountName
                displayName        = $testKrbTgtObjectName
                userAccountControl = 514
                unicodePwd         = $krbTgtPassword
                description        = $testKrbTgtObjectDescription
            }
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    Add-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $testKrbTgtObj -BinaryProps unicodePwd
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Creating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbTgtObjectSamAccountName'..." -Level ERROR
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
                    Add-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $testKrbTgtObj -BinaryProps unicodePwd
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Creating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbTgtObjectSamAccountName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                }
            }
        } Catch {
            Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] FAILED TO BE CREATED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
            Write-Log -Message "" -Level ERROR
        }

        # Check The The Test/Bogus KrbTgt Account Exists And Was created In AD
        $testKrbTgtObject = $null
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectClass=user)(name=$testKrbTgtObjectName))"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'name=$testKrbTgtObjectName'..." -Level ERROR
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
                $testKrbTgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectClass=user)(name=$testKrbTgtObjectName))"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'name=$testKrbTgtObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
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
            $testKrbTgtObjectDN = $testKrbTgtObject.DistinguishedName
            Write-Log -Message "  --> New Test KrbTgt Account [$testKrbTgtObjectDN] CREATED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
            $updateMembership = $true
        } Else {
            $updateMembership = $false
        }
    }

    If ($testKrbTgtObject -And $updateMembership -eq $true) {
        # If The Test/Bogus KrbTgt Account Already Exists In AD
        # If The Test/Bogus KrbTgt Account Is Not Yet A Member Of The Specified AD Group, Then Add It As A Member
        If ($KrbTgtUse -eq "RWDC") {
            # If The Test/Bogus KrbTgt Account Is Used By RWDCs
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    $deniedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectClass=group)(sAMAccountName=$deniedRODCPwdReplGroupObjectName))" -AdditionalProperties @('member')
                    $deniedRODCPwdReplGroupObject.member = $testKrbTgtObjectDN
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $deniedRODCPwdReplGroupObject -Mode Add
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Adding Members On '$TargetedADDomainRWDCFQDN' For Group Object With 'name=$deniedRODCPwdReplGroupObjectName'..." -Level ERROR
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
                    $deniedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectClass=group)(sAMAccountName=$deniedRODCPwdReplGroupObjectName))" -AdditionalProperties @('member')
                    $deniedRODCPwdReplGroupObject.member = $testKrbTgtObjectDN
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $deniedRODCPwdReplGroupObject -Mode Add
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Retrieving Members On '$TargetedADDomainRWDCFQDN' For Group Object With 'name=$deniedRODCPwdReplGroupObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                }
            }
            Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] ADDED AS MEMBER OF [$deniedRODCPwdReplGroupObjectName]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
        }

        If ($KrbTgtUse -eq "RODC") {
            # If The Test/Bogus KrbTgt Account Is Used By RODCs
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    $allowedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectClass=group)(sAMAccountName=$allowedRODCPwdReplGroupObjectName))" -AdditionalProperties @('member')
                    $allowedRODCPwdReplGroupObject.member = $testKrbTgtObjectDN
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $allowedRODCPwdReplGroupObject -Mode Add
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Adding Members On '$TargetedADDomainRWDCFQDN' For Group Object With 'name=$allowedRODCPwdReplGroupObjectName'..." -Level ERROR
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
                    $allowedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectClass=group)(sAMAccountName=$allowedRODCPwdReplGroupObjectName))" -AdditionalProperties @('member')
                    $allowedRODCPwdReplGroupObject.member = $testKrbTgtObjectDN
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $allowedRODCPwdReplGroupObject -Mode Add
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Retrieving Members On '$TargetedADDomainRWDCFQDN' For Group Object With 'name=$allowedRODCPwdReplGroupObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                }
            }
            Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] ADDED AS MEMBER OF [$allowedRODCPwdReplGroupObjectName]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
        }
    } ElseIf ($testKrbTgtObject -And $updateMembership -eq $false) {
        # If The Test/Bogus KrbTgt Account Is Already A Member Of The Specified AD Group
        If ($KrbTgtUse -eq "RWDC") {
            Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] ALREADY MEMBER OF [$deniedRODCPwdReplGroupObjectName]!..." -Level REMARK
        }
        If ($KrbTgtUse -eq "RODC") {
            Write-Log -Message "  --> Test KrbTgt Account [$testKrbTgtObjectDN] ALREADY MEMBER OF [$allowedRODCPwdReplGroupObjectName]!..." -Level REMARK
        }
        Write-Log -Message "" -Level REMARK
    }
}
