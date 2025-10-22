function Remove-TestKrbTgtAccount {
    <#
    .SYNOPSIS
        Removes TEST/BOGUS KrbTgt accounts
    
    .DESCRIPTION
        Removes TEST KrbTgt accounts that were created for testing purposes.
        
        For RWDCs: Removes 'krbtgt_TEST' account
        For RODCs: Removes 'krbtgt_<Number>_TEST' accounts (one per RODC)
        
        This corresponds to Mode 9 in the original script.
    
    .PARAMETER TargetDomain
        FQDN of the target Active Directory domain
    
    .PARAMETER Credential
        PSCredential for authentication (if targeting remote domain)
    
    .EXAMPLE
        Remove-TestKrbTgtAccount -TargetDomain "contoso.com"
        
        Removes TEST KrbTgt accounts from the contoso.com domain
    
    .EXAMPLE
        Remove-TestKrbTgtAccount -TargetDomain "child.contoso.com" -Credential (Get-Credential)
        
        Removes TEST KrbTgt accounts using alternate credentials
    
    .NOTES
        Requires Domain Admin or Enterprise Admin permissions
        Only removes TEST accounts (_TEST suffix)
        Will not remove production KrbTgt accounts
    
    .LINK
        New-TestKrbTgtAccount
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetDomain,
        
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )
    
    begin {
        Write-Verbose "Remove-TestKrbTgtAccount: BEGIN block"
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
        Write-Log -Message "CLEANUP TEST KRBTGT ACCOUNTS (MODE 9)..." -Level HEADER
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
        Write-Verbose "Remove-TestKrbTgtAccount: PROCESS block"
        
        try {
            # Ask for confirmation
            Write-Log -Message "Do you really want to continue and delete TEST KrbTgt accounts? [CONTINUE | STOP]: " -Level "ACTION-NO-NEW-LINE"
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
            
            # Get domain DN
            $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
            $domainDN = $rootDSE.defaultNamingContext.distinguishedName
            
            # ===== REMOVE RWDC TEST ACCOUNT =====
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "+++ Delete Test KrbTgt Account...: 'krbtgt_TEST' +++" -Level REMARK
            Write-Log -Message "+++ Used By RWDC.................: 'All RWDCs' +++" -Level REMARK
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "" -Level REMARK
            
            if ($PSCmdlet.ShouldProcess("krbtgt_TEST on $targetRWDCFQDN", "Delete TEST account")) {
                Remove-InternalTestKrbTgtAccount `
                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                    -KrbTgtSamAccountName "krbtgt_TEST" `
                    -LocalADForest $localADForest `
                    -AdminCredentials $adminCreds
            }
            
            # ===== REMOVE RODC TEST ACCOUNTS =====
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
                            Write-Log -Message "+++ Delete Test KrbTgt Account...: '$krbTgtSamAccountName' +++" -Level REMARK
                            Write-Log -Message "+++ Used By RODC.................: '$rodcFQDN' (Site: $rodcSiteName) +++" -Level REMARK
                            Write-Log -Message "+++++" -Level REMARK
                            Write-Log -Message "" -Level REMARK
                            
                            if ($PSCmdlet.ShouldProcess("$krbTgtSamAccountName on $targetRWDCFQDN", "Delete TEST account")) {
                                Remove-InternalTestKrbTgtAccount `
                                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                                    -KrbTgtSamAccountName $krbTgtSamAccountName `
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
            Write-Log -Message "ERROR removing TEST accounts: $_" -Level ERROR
            throw
        }
    }
    
    end {
        Write-Verbose "Remove-TestKrbTgtAccount: END block"
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
    }
}
