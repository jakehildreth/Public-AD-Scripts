function New-TestKrbtgtAccount {
    <#
    .SYNOPSIS
        Creates TEST/BOGUS Krbtgt accounts for testing purposes
    
    .DESCRIPTION
        Creates TEST Krbtgt accounts that can be used to test the password reset
        process without affecting production accounts.
        
        For RWDCs: Creates 'krbtgt_TEST' account
        For RODCs: Creates 'krbtgt_<Number>_TEST' accounts (one per RODC)
        
        This corresponds to Mode 8 in the original script.
    
    .PARAMETER TargetDomain
        FQDN of the target Active Directory domain
    
    .PARAMETER Credential
        PSCredential for authentication (if targeting remote domain)
    
    .EXAMPLE
        New-TestKrbtgtAccount -TargetDomain "contoso.com"
        
        Creates TEST Krbtgt accounts in the contoso.com domain
    
    .EXAMPLE
        New-TestKrbtgtAccount -TargetDomain "child.contoso.com" -Credential (Get-Credential)
        
        Creates TEST Krbtgt accounts using alternate credentials
    
    .EXAMPLE
        "contoso.com", "fabrikam.com" | New-TestKrbtgtAccount
        
        Creates TEST Krbtgt accounts for multiple domains via pipeline
    
    .OUTPUTS
        None. Creation status is displayed via logging output.
    
    .NOTES
        Requires Domain Admin or Enterprise Admin permissions
        TEST accounts are created in disabled state
        RWDC TEST account is added to "Denied RODC Password Replication Group"
        RODC TEST accounts are added to "Allowed RODC Password Replication Group"
    
    .LINK
        Remove-TestKrbtgtAccount
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
        Write-Verbose "New-TestKrbtgtAccount: BEGIN block"
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
        Write-Verbose "New-TestKrbtgtAccount: PROCESS block"
        
        try {
            # ShouldProcess confirmation replaces Read-Host prompt
            if (-not $PSCmdlet.ShouldProcess($TargetDomain, "Create TEST Krbtgt accounts")) {
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
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Unable to retrieve domain SID for $TargetDomain"),
                    'DomainSIDNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $TargetDomain
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            
            # ===== CREATE RWDC TEST ACCOUNT =====
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "+++ Create Test Krbtgt Account...: 'krbtgt_TEST' +++" -Level REMARK
            Write-Log -Message "+++ Used By RWDC.................: 'All RWDCs' +++" -Level REMARK
            Write-Log -Message "+++++" -Level REMARK
            Write-Log -Message "" -Level REMARK
            
            if ($PSCmdlet.ShouldProcess("krbtgt_TEST on $targetRWDCFQDN", "Create TEST account")) {
                New-InternalTestKrbtgtAccount `
                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                    -KrbtgtSamAccountName "krbtgt_TEST" `
                    -KrbtgtUse "RWDC" `
                    -TargetedADDomainDomainSID $domainSID `
                    -LocalADForest $localADForest `
                    -AdminCredentials $adminCreds
            }
            
            # ===== CREATE RODC TEST ACCOUNTS =====
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
                            Write-Log -Message "+++ Create Test Krbtgt Account...: '$krbTgtSamAccountName' +++" -Level REMARK
                            Write-Log -Message "+++ Used By RODC.................: '$rodcFQDN' (Site: $rodcSiteName) +++" -Level REMARK
                            Write-Log -Message "+++++" -Level REMARK
                            Write-Log -Message "" -Level REMARK
                            
                            if ($PSCmdlet.ShouldProcess("$krbTgtSamAccountName on $targetRWDCFQDN", "Create TEST account")) {
                                New-InternalTestKrbtgtAccount `
                                    -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                                    -KrbtgtInUseByDCFQDN $rodcFQDN `
                                    -KrbtgtSamAccountName $krbTgtSamAccountName `
                                    -KrbtgtUse "RODC" `
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
            Write-Log -Message "All TEST Krbtgt accounts have been processed." -Level SUCCESS
            Write-Log -Message "" -Level REMARK
        }
        catch {
            Write-Log -Message "ERROR creating TEST accounts: $_" -Level ERROR
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $_.Exception,
                'TestAccountCreationFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $TargetDomain
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
    
    end {
        Write-Verbose "New-TestKrbtgtAccount: END block"
        Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
    }
}
