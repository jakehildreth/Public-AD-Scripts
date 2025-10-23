function Remove-TestKrbtgtAccount {
    <#
    .SYNOPSIS
        Removes TEST/BOGUS Krbtgt accounts
    
    .DESCRIPTION
        Removes TEST Krbtgt accounts that were created for testing purposes.
        
        For RWDCs: Removes 'krbtgt_TEST' account
        For RODCs: Removes 'krbtgt_<Number>_TEST' accounts (one per RODC)
        
        This corresponds to Mode 9 in the original script.
    
    .PARAMETER TargetDomain
        FQDN of the target Active Directory domain
    
    .PARAMETER Credential
        PSCredential for authentication (if targeting remote domain)
    
    .EXAMPLE
        Remove-TestKrbtgtAccount -TargetDomain "contoso.com"
        
        Removes TEST Krbtgt accounts from the contoso.com domain
    
    .EXAMPLE
        Remove-TestKrbtgtAccount -TargetDomain "child.contoso.com" -Credential (Get-Credential)
        
        Removes TEST Krbtgt accounts using alternate credentials
    
    .EXAMPLE
        "contoso.com", "fabrikam.com" | Remove-TestKrbtgtAccount
        
        Removes TEST Krbtgt accounts from multiple domains via pipeline
    
    .OUTPUTS
        None. Removal status is displayed via logging output.
    
    .NOTES
        Requires Domain Admin or Enterprise Admin permissions
        Only removes TEST accounts (_TEST suffix)
        Will not remove production Krbtgt accounts
    
    .LINK
        New-TestKrbtgtAccount
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetDomain,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    begin {
        Write-Verbose "Remove-TestKrbtgtAccount: BEGIN block"
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
        Write-Verbose "Remove-TestKrbtgtAccount: PROCESS block"
        
        try {
            # ShouldProcess confirmation replaces Read-Host prompt
            if (-not $PSCmdlet.ShouldProcess($TargetDomain, "Remove TEST Krbtgt accounts")) {
                Write-Verbose "Operation cancelled by user via ShouldProcess"
                return
            }
            
            # Get domain controllers
            Write-Verbose "Discovering domain controllers in $TargetDomain"
            $dcList = Get-ADDomainControllers -DomainFQDN $TargetDomain -Credential $adminCreds
            
            if (-not $dcList -or $dcList.Count -eq 0) {
                Write-Log -Message "No domain controllers found in $TargetDomain" -Level ERROR
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("No domain controllers found in $TargetDomain"),
                    'NoDomainControllersFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $TargetDomain
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            
            # Find PDC FSMO holder
            $pdcFSMO = $dcList | Where-Object { $_.IsPDC -eq $true } | Select-Object -First 1
            
            if (-not $pdcFSMO) {
                Write-Log -Message "Unable to locate PDC FSMO holder in $TargetDomain" -Level ERROR
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Unable to locate PDC FSMO holder in $TargetDomain"),
                    'PDCFSMONotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $TargetDomain
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            
            $targetRWDCFQDN = $pdcFSMO.HostName
            
            # Get domain DN
            $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
            $domainDN = $rootDSE.defaultNamingContext.distinguishedName
            
            # ===== REMOVE RWDC TEST ACCOUNT =====
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "+++ Delete Test Krbtgt Account...: 'krbtgt_TEST' +++" -Level REMARK
            Write-Log -Message "+++ Used By RWDC.................: 'All RWDCs' +++" -Level REMARK
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "" -Level REMARK
            
            if ($PSCmdlet.ShouldProcess("krbtgt_TEST on $targetRWDCFQDN", "Delete TEST account")) {
                Remove-InternalTestKrbtgtAccount `
                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                    -KrbtgtSamAccountName "krbtgt_TEST" `
                    -LocalADForest $localADForest `
                    -AdminCredentials $adminCreds
            }
            
            # ===== REMOVE RODC TEST ACCOUNTS =====
            $rodcs = $dcList | Where-Object { $_.IsRODC -eq $true }
            
            foreach ($rodc in $rodcs) {
                $rodcFQDN = $rodc.HostName
                $rodcSiteName = $rodc.SiteName
                
                # Get the RODC's krbtgt account number from msDS-KrbtgtLink attribute
                try {
                    $rodcComputerObj = Find-LdapObject `
                        -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                        -searchBase $domainDN `
                        -searchFilter "(&(objectClass=computer)(dNSHostName=$rodcFQDN))" `
                        -PropertiesToLoad @("msDS-KrbtgtLink")
                    
                    if ($rodcComputerObj -and $rodcComputerObj.'msDS-KrbtgtLink') {
                        # Extract krbtgt account DN
                        $krbTgtDN = $rodcComputerObj.'msDS-KrbtgtLink'
                        
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
                            Write-Log -Message "+++ Delete Test Krbtgt Account...: '$krbTgtSamAccountName' +++" -Level REMARK
                            Write-Log -Message "+++ Used By RODC.................: '$rodcFQDN' (Site: $rodcSiteName) +++" -Level REMARK
                            Write-Log -Message "+++++" -Level REMARK
                            Write-Log -Message "" -Level REMARK
                            
                            if ($PSCmdlet.ShouldProcess("$krbTgtSamAccountName on $targetRWDCFQDN", "Delete TEST account")) {
                                Remove-InternalTestKrbtgtAccount `
                                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                                    -KrbtgtSamAccountName $krbTgtSamAccountName `
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
            Write-Log -Message "All TEST Krbtgt accounts have been processed." -Level SUCCESS
            Write-Log -Message "" -Level REMARK
        }
        catch {
            Write-Log -Message "ERROR removing TEST accounts: $_" -Level ERROR
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'TestAccountRemovalFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $TargetDomain
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
    
    end {
        Write-Verbose "Remove-TestKrbtgtAccount: END block"
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
    }
}
