Function New-InternalTestKrbtgtAccount {
    <#
    .SYNOPSIS
        Creates or updates a TEST Krbtgt account in Active Directory.

    .DESCRIPTION
        Creates a test/bogus Krbtgt account (krbtgt_TEST or krbtgt_<Number>_TEST for RODCs) for
        testing purposes. For RWDC accounts, adds to Denied RODC Password Replication Group.
        For RODC accounts, adds to Allowed RODC Password Replication Group.
        If the account already exists, updates description and group membership as needed.

    .PARAMETER TargetedADDomainRWDCFQDN
        The FQDN of the RWDC where the TEST account will be created/updated.

    .PARAMETER KrbtgtInUseByDCFQDN
        For RODC accounts, the FQDN of the RODC that uses this Krbtgt account.

    .PARAMETER KrbtgtSamAccountName
        The SamAccountName for the TEST Krbtgt account (e.g., "krbtgt_TEST" or "krbtgt_12345_TEST").

    .PARAMETER KrbtgtUse
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
        Author: Original function from Reset-Krbtgt-Password-For-RWDCs-And-RODCs.ps1 v3.4
        Modified: Extracted to modular structure for Reset-KrbtgtPassword v4.0.0
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
        [string]$KrbtgtInUseByDCFQDN,

        [Parameter(Mandatory = $true)]
        [string]$KrbtgtSamAccountName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("RWDC", "RODC")]
        [string]$KrbtgtUse,

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
    $containerForTestKrbtgtAccount = "CN=Users," + $targetedADdomainDefaultNC

    # Set The SamAccountName For The Test/Bogus Krbtgt Account
    $testKrbtgtObjectSamAccountName = $KrbtgtSamAccountName

    # Set The Name For The Test/Bogus Krbtgt Account
    $testKrbtgtObjectName = $testKrbtgtObjectSamAccountName

    # Set The Description For The Test/Bogus Krbtgt Account
    $testKrbtgtObjectDescription = $null

    # Set The Description For The Test/Bogus Krbtgt Account For RWDCs
    If ($KrbtgtUse -eq "RWDC") {
        $testKrbtgtObjectDescription = "Test Copy Representing '$($KrbtgtSamAccountName.SubString(0,$KrbtgtSamAccountName.IndexOf('_TEST')))' - Key Distribution Center Service Account For RWDCs"
    }

    # Set The Description For The Test/Bogus Krbtgt Account For RODCs
    If ($KrbtgtUse -eq "RODC") {
        $testKrbtgtObjectDescription = "Test Copy Representing '$($KrbtgtSamAccountName.SubString(0,$KrbtgtSamAccountName.IndexOf('_TEST')))' - Key Distribution Center Service Account For RODC '$KrbtgtInUseByDCFQDN'"
    }

    # Generate The DN Of The Test Krbtgt Object
    $testKrbtgtObjectDN = "CN=" + $testKrbtgtObjectName + "," + $containerForTestKrbtgtAccount

    # Display Information About The Test Krbtgt To Be Created/Edited
    Write-Log -Message "  --> RWDC To Create/Update Object On.......: '$TargetedADDomainRWDCFQDN'"
    Write-Log -Message "  --> Full Name Test Krbtgt Account.........: '$testKrbtgtObjectName'"
    Write-Log -Message "  --> Description...........................: '$testKrbtgtObjectDescription'"
    Write-Log -Message "  --> Container Test Krbtgt Account.........: '$containerForTestKrbtgtAccount'"
    If ($KrbtgtUse -eq "RWDC") {
        Write-Log -Message "  --> To Be Used By DC(s)...................: 'All RWDCs'"
    }
    If ($KrbtgtUse -eq "RODC") {
        Write-Log -Message "  --> To Be Used By RODC....................: '$KrbtgtInUseByDCFQDN'"
    }

    # If The Test/Bogus Krbtgt Account Is Used By RWDCs
    $deniedRODCPwdReplGroupObjectDN = $null
    $deniedRODCPwdReplGroupObjectName = $null
    If ($KrbtgtUse -eq "RWDC") {
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

    # If The Test/Bogus Krbtgt Account Is Used By RODCs
    $allowedRODCPwdReplGroupObjectDN = $null
    $allowedRODCPwdReplGroupObjectName = $null
    If ($KrbtgtUse -eq "RODC") {
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

    # Check If The Test/Bogus Krbtgt Account Already Exists In AD
    $testKrbtgtObject = $null
    If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
        Try {
            $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
            $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbtgtObjectDN)" -PropertiesToLoad @("description")
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
            $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(distinguishedName=$testKrbtgtObjectDN)" -PropertiesToLoad @("description")
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

    $updateMembership = $false
    If ($testKrbtgtObject) {
        Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] ALREADY EXISTS on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
        Write-Log -Message "" -Level REMARK

        # Update The Description For The Test Krbtgt Account If There Is A Mismatch For Whatever Reason
        If ($testKrbtgtObject.Description -ne $testKrbtgtObjectDescription) {
            $testKrbtgtObj = [PSCustomObject]@{
                distinguishedName = $testKrbtgtObjectDN
                description       = $testKrbtgtObjectDescription
            }
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Mode Replace -Object $testKrbtgtObj
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Updating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbtgtObjectSamAccountName'..." -Level ERROR
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
                    Edit-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Mode Replace -Object $testKrbtgtObj
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Updating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbtgtObjectSamAccountName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Type......: $($_.Exception.GetType().FullName)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Exception Message...: $($_.Exception.Message)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
                    Write-Log -Message "" -Level ERROR
                }
            }
            Write-Log -Message "  --> Updated Description For Existing Test Krbtgt Account [$testKrbtgtObjectDN] on RWDC [$TargetedADDomainRWDCFQDN] Due To Mismatch!..." -Level REMARK
        }

        # Check The Membership Of The Test Krbtgt Accounts And Update As Needed
        If ($KrbtgtUse -eq "RWDC") {
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbtgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$deniedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbtgtObjectSamAccountName' For Object '$deniedRODCPwdReplGroupObjectName'..." -Level ERROR
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
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbtgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$deniedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbtgtObjectSamAccountName' For Object '$deniedRODCPwdReplGroupObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
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
        If ($KrbtgtUse -eq "RODC") {
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbtgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$allowedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbtgtObjectSamAccountName' For Object '$allowedRODCPwdReplGroupObjectName'..." -Level ERROR
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
                    If (!(Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$testKrbtgtObjectSamAccountName)(memberOf:1.2.840.113556.1.4.1941:=$allowedRODCPwdReplGroupObjectDN))")) {
                        $updateMembership = $true
                    }
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Checking Membership On '$TargetedADDomainRWDCFQDN' Of Object '$testKrbtgtObjectSamAccountName' For Object '$allowedRODCPwdReplGroupObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
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
        # If The Test/Bogus Krbtgt Account Does Not Exist Yet In AD
        # Specify The Number Of Characters The Generate Password Should Contain
        $passwdNrChars = 64

        # Generate A New Password With The Specified Length (Text)
        $krbTgtPassword = $null
        $krbTgtPassword = (New-ComplexPassword -Length $passwdNrChars).ToString()

        # Try To Create The Test/Bogus Krbtgt Account In The AD Domain And If Not Successfull Throw Error
        Try {
            $testKrbtgtObj = [PSCustomObject]@{
                distinguishedName  = $testKrbtgtObjectDN
                objectClass        = "user"
                sAMAccountName     = $testKrbtgtObjectSamAccountName
                displayName        = $testKrbtgtObjectName
                userAccountControl = 514
                unicodePwd         = $krbTgtPassword
                description        = $testKrbtgtObjectDescription
            }
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    Add-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -Object $testKrbtgtObj -BinaryProps unicodePwd
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Creating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbtgtObjectSamAccountName'..." -Level ERROR
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
                    Add-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -Object $testKrbtgtObj -BinaryProps unicodePwd
                } Catch {
                    Write-Log -Message "" -Level ERROR
                    Write-Log -Message "Error Creating User On '$TargetedADDomainRWDCFQDN' For Object '$testKrbtgtObjectSamAccountName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
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
            Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] FAILED TO BE CREATED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level ERROR
            Write-Log -Message "" -Level ERROR
        }

        # Check The The Test/Bogus Krbtgt Account Exists And Was created In AD
        $testKrbtgtObject = $null
        If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
            Try {
                $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectClass=user)(name=$testKrbtgtObjectName))"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'name=$testKrbtgtObjectName'..." -Level ERROR
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
                $testKrbtgtObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos -Credential $AdminCredentials) -searchBase $targetSearchBase -searchFilter "(&(objectClass=user)(name=$testKrbtgtObjectName))"
            } Catch {
                Write-Log -Message "" -Level ERROR
                Write-Log -Message "Error Querying AD Against '$TargetedADDomainRWDCFQDN' For User Object With 'name=$testKrbtgtObjectName' Using '$($AdminCredentials.UserName)'..." -Level ERROR
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
            $testKrbtgtObjectDN = $testKrbtgtObject.DistinguishedName
            Write-Log -Message "  --> New Test Krbtgt Account [$testKrbtgtObjectDN] CREATED on RWDC [$TargetedADDomainRWDCFQDN]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
            $updateMembership = $true
        } Else {
            $updateMembership = $false
        }
    }

    If ($testKrbtgtObject -And $updateMembership -eq $true) {
        # If The Test/Bogus Krbtgt Account Already Exists In AD
        # If The Test/Bogus Krbtgt Account Is Not Yet A Member Of The Specified AD Group, Then Add It As A Member
        If ($KrbtgtUse -eq "RWDC") {
            # If The Test/Bogus Krbtgt Account Is Used By RWDCs
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    $deniedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectClass=group)(sAMAccountName=$deniedRODCPwdReplGroupObjectName))" -AdditionalProperties @('member')
                    $deniedRODCPwdReplGroupObject.member = $testKrbtgtObjectDN
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
                    $deniedRODCPwdReplGroupObject.member = $testKrbtgtObjectDN
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
            Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] ADDED AS MEMBER OF [$deniedRODCPwdReplGroupObjectName]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
        }

        If ($KrbtgtUse -eq "RODC") {
            # If The Test/Bogus Krbtgt Account Is Used By RODCs
            If ($LocalADForest -eq $true -Or ($LocalADForest -eq $false -And !$AdminCredentials)) {
                Try {
                    $targetSearchBase = (Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos)).defaultNamingContext.distinguishedName
                    $allowedRODCPwdReplGroupObject = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$TargetedADDomainRWDCFQDN -EncryptionType Kerberos) -searchBase $targetSearchBase -searchFilter "(&(objectClass=group)(sAMAccountName=$allowedRODCPwdReplGroupObjectName))" -AdditionalProperties @('member')
                    $allowedRODCPwdReplGroupObject.member = $testKrbtgtObjectDN
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
                    $allowedRODCPwdReplGroupObject.member = $testKrbtgtObjectDN
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
            Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] ADDED AS MEMBER OF [$allowedRODCPwdReplGroupObjectName]!..." -Level REMARK
            Write-Log -Message "" -Level REMARK
        }
    } ElseIf ($testKrbtgtObject -And $updateMembership -eq $false) {
        # If The Test/Bogus Krbtgt Account Is Already A Member Of The Specified AD Group
        If ($KrbtgtUse -eq "RWDC") {
            Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] ALREADY MEMBER OF [$deniedRODCPwdReplGroupObjectName]!..." -Level REMARK
        }
        If ($KrbtgtUse -eq "RODC") {
            Write-Log -Message "  --> Test Krbtgt Account [$testKrbtgtObjectDN] ALREADY MEMBER OF [$allowedRODCPwdReplGroupObjectName]!..." -Level REMARK
        }
        Write-Log -Message "" -Level REMARK
    }
}
