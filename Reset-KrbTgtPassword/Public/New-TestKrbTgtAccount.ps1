function New-TestKrbTgtAccount {
    <#
    .SYNOPSIS
        Creates TEST/BOGUS KrbTgt accounts for testing purposes
    
    .DESCRIPTION
        Creates TEST KrbTgt accounts that can be used to test the password reset
        process without affecting production accounts.
        
        For RWDCs: Creates 'krbtgt_TEST' account
        For RODCs: Creates 'krbtgt_<Number>_TEST' accounts (one per RODC)
        
        This corresponds to Mode 8 in the original script.
    
    .PARAMETER TargetDomain
        FQDN of the target Active Directory domain
    
    .PARAMETER Credential
        PSCredential for authentication (if targeting remote domain)
    
    .EXAMPLE
        New-TestKrbTgtAccount -TargetDomain "contoso.com"
        
        Creates TEST KrbTgt accounts in the contoso.com domain
    
    .EXAMPLE
        New-TestKrbTgtAccount -TargetDomain "child.contoso.com" -Credential (Get-Credential)
        
        Creates TEST KrbTgt accounts using alternate credentials
    
    .NOTES
        Requires Domain Admin or Enterprise Admin permissions
        TEST accounts are created in disabled state
        RWDC TEST account is added to "Denied RODC Password Replication Group"
        RODC TEST accounts are added to "Allowed RODC Password Replication Group"
    
    .LINK
        Remove-TestKrbTgtAccount
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetDomain,
        
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )
    
    begin {
        Write-Verbose "New-TestKrbTgtAccount: BEGIN block"
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
        Write-Log -Message "CREATE TEST KRBTGT ACCOUNTS (MODE 8)..." -Level HEADER
        Write-Log -Message ""
        
        # Determine if local or remote forest
        $localADForest = $true
        $adminCreds = $null
        
        if ($Credential) {
            $localADForest = $false
            $adminCreds = $Credential
        }
    }
    
    process {
        Write-Verbose "New-TestKrbTgtAccount: PROCESS block"
        
        try {
            # Ask for confirmation
            Write-Log -Message "Do you really want to continue and create TEST KrbTgt accounts? [CONTINUE | STOP]: " -Level "ACTION-NO-NEW-LINE"
            $continueOrStop = Read-Host
            
            if ($continueOrStop.ToUpper() -ne "CONTINUE") {
                Write-Log -Message "" -Level REMARK
                Write-Log -Message "  --> Chosen: STOP" -Level REMARK
                Write-Log -Message "" -Level WARNING
                Write-Log -Message "Operation cancelled by user." -Level WARNING
                return
            }
            
            Write-Log -Message "" -Level REMARK
            Write-Log -Message "  --> Chosen: CONTINUE" -Level REMARK
            Write-Log -Message "" -Level REMARK
            
            # Get domain controllers
            Write-Verbose "Discovering domain controllers in $TargetDomain"
            $dcList = Get-ADDomainControllers -DomainFQDN $TargetDomain -Credential $adminCreds
            
            if (-not $dcList -or $dcList.Count -eq 0) {
                Write-Log -Message "No domain controllers found in $TargetDomain" -Level ERROR
                return
            }
            
            # Find PDC FSMO holder
            $pdcFSMO = $dcList | Where-Object { $_.IsPDC -eq $true } | Select-Object -First 1
            
            if (-not $pdcFSMO) {
                Write-Log -Message "Unable to locate PDC FSMO holder in $TargetDomain" -Level ERROR
                return
            }
            
            $targetRWDCFQDN = $pdcFSMO.HostName
            
            # Get domain SID (required for group lookups)
            $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
            $domainDN = $rootDSE.defaultNamingContext.distinguishedName
            
            # Query domain object for SID
            $domainObj = Find-LdapObject -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                -searchBase $domainDN -searchFilter "(objectClass=domain)" -searchScope Base -PropertiesToLoad @("objectSid") -BinaryProps @("objectSid")
            
            if ($domainObj -and $domainObj.objectSid) {
                $domainSID = (New-Object System.Security.Principal.SecurityIdentifier($domainObj.objectSid, 0)).Value
            } else {
                Write-Log -Message "Unable to retrieve domain SID" -Level ERROR
                return
            }
            
            # ===== CREATE RWDC TEST ACCOUNT =====
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "+++ Create Test KrbTgt Account...: 'krbtgt_TEST' +++" -Level REMARK
            Write-Log -Message "+++ Used By RWDC.................: 'All RWDCs' +++" -Level REMARK
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "" -Level REMARK
            
            if ($PSCmdlet.ShouldProcess("krbtgt_TEST on $targetRWDCFQDN", "Create TEST account")) {
                New-InternalTestKrbTgtAccount `
                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                    -KrbTgtSamAccountName "krbtgt_TEST" `
                    -KrbTgtUse "RWDC" `
                    -TargetedADDomainDomainSID $domainSID `
                    -LocalADForest $localADForest `
                    -AdminCredentials $adminCreds
            }
            
            # ===== CREATE RODC TEST ACCOUNTS =====
            $rodcs = $dcList | Where-Object { $_.IsRODC -eq $true }
            
            foreach ($rodc in $rodcs) {
                $rodcFQDN = $rodc.HostName
                $rodcSiteName = $rodc.SiteName
                
                # Get the RODC's krbtgt account number from msDS-KrbTgtLink attribute
                try {
                    $rodcComputerObj = Find-LdapObject `
                        -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                        -searchBase $domainDN `
                        -searchFilter "(&(objectClass=computer)(dNSHostName=$rodcFQDN))" `
                        -PropertiesToLoad @("msDS-KrbTgtLink")
                    
                    if ($rodcComputerObj -and $rodcComputerObj.'msDS-KrbTgtLink') {
                        # Extract krbtgt account DN
                        $krbTgtDN = $rodcComputerObj.'msDS-KrbTgtLink'
                        
                        # Get the krbtgt account to extract the sAMAccountName
                        $krbTgtObj = Find-LdapObject `
                            -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                            -searchBase $krbTgtDN `
                            -searchFilter "(objectClass=user)" `
                            -searchScope Base `
                            -PropertiesToLoad @("sAMAccountName")
                        
                        if ($krbTgtObj) {
                            $krbTgtSamAccountName = $krbTgtObj.sAMAccountName + "_TEST"
                            
                            Write-Log -Message "+++++" -Level REMARK
                            Write-Log -Message "+++ Create Test KrbTgt Account...: '$krbTgtSamAccountName' +++" -Level REMARK
                            Write-Log -Message "+++ Used By RODC.................: '$rodcFQDN' (Site: $rodcSiteName) +++" -Level REMARK
                            Write-Log -Message "+++++" -Level REMARK
                            Write-Log -Message "" -Level REMARK
                            
                            if ($PSCmdlet.ShouldProcess("$krbTgtSamAccountName on $targetRWDCFQDN", "Create TEST account")) {
                                New-InternalTestKrbTgtAccount `
                                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                                    -KrbTgtInUseByDCFQDN $rodcFQDN `
                                    -KrbTgtSamAccountName $krbTgtSamAccountName `
                                    -KrbTgtUse "RODC" `
                                    -TargetedADDomainDomainSID $domainSID `
                                    -LocalADForest $localADForest `
                                    -AdminCredentials $adminCreds
                            }
                        }
                    }
                } catch {
                    Write-Log -Message "Error processing RODC $rodcFQDN`: $($_.Exception.Message)" -Level ERROR
                }
            }
            
            Write-Log -Message "" -Level REMARK
            Write-Log -Message "All TEST KrbTgt accounts have been processed." -Level SUCCESS
            Write-Log -Message "" -Level REMARK
        }
        catch {
            Write-Log -Message "ERROR creating TEST accounts: $_" -Level ERROR
            throw
        }
    }
    
    end {
        Write-Verbose "New-TestKrbTgtAccount: END block"
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
    }
}
