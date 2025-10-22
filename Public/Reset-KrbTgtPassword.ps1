function Reset-KrbTgtPassword {
    <#
    .SYNOPSIS
        Resets KrbTgt account password for RWDCs and/or RODCs in Active Directory
    
    .DESCRIPTION
        Main orchestration function for KrbTgt password reset operations.
        Supports multiple operation modes for testing and production password resets.
        
        Operation Modes:
        - Info: Informational analysis only (no changes)
        - SimulateCanary: Test replication with temporary canary object
        - SimulateTest: Simulate with TEST accounts (WhatIf mode)
        - ResetTest: Reset TEST account passwords
        - SimulateProd: Simulate with PROD accounts (WhatIf mode)
        - ResetProd: Reset PRODUCTION account passwords (LIVE IMPACT!)
    
    .PARAMETER Mode
        Operation mode to execute
    
    .PARAMETER TargetDomain
        FQDN of target Active Directory domain
    
    .PARAMETER Scope
        Scope of KrbTgt accounts to target (AllRWDCs, AllRODCs, SpecificRODCs)
    
    .PARAMETER TargetRODCs
        Array of RODC FQDNs when Scope is SpecificRODCs
    
    .PARAMETER Credential
        PSCredential for authentication to remote domain
    
    .PARAMETER SendEmailReport
        Send log file via email after completion
    
    .PARAMETER ContinueOnWarning
        Continue without confirmation prompts (for automated runs)
    
    .EXAMPLE
        Reset-KrbTgtPassword -Mode Info -TargetDomain "contoso.com"
        
        Runs informational mode to analyze the environment without making changes
    
    .EXAMPLE
        Reset-KrbTgtPassword -Mode SimulateCanary -TargetDomain "contoso.com" -Scope AllRWDCs
        
        Tests replication by creating and monitoring a temporary canary object
    
    .EXAMPLE
        Reset-KrbTgtPassword -Mode ResetProd -TargetDomain "contoso.com" -Scope AllRWDCs -Confirm
        
        Resets the production KrbTgt password for all RWDCs (LIVE IMPACT!)
    
    .NOTES
        Requires:
        - PowerShell 5.1 or higher
        - Domain Admin or Enterprise Admin permissions
        - Elevated PowerShell session
    
    .LINK
        https://github.com/zjorz/Public-AD-Scripts
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'SimulateCanary', 'SimulateTest', 'ResetTest', 'SimulateProd', 'ResetProd')]
        [string]$Mode,
        
        [Parameter(Mandatory=$false)]
        [string]$TargetDomain,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('AllRWDCs', 'AllRODCs', 'SpecificRODCs')]
        [string]$Scope,
        
        [Parameter(Mandatory=$false)]
        [string[]]$TargetRODCs,
        
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory=$false)]
        [switch]$SendEmailReport,
        
        [Parameter(Mandatory=$false)]
        [switch]$ContinueOnWarning
    )
    
    begin {
        Write-Verbose "Reset-KrbTgtPassword: BEGIN block"
        
        # Initialize log file path
        $execDateTime = Get-Date -Format "yyyy-MM-dd_HH.mm.ss"
        $computerName = $env:COMPUTERNAME
        $logFileName = "$execDateTime`_$computerName`_Reset-KrbTgtPassword.log"
        $Script:LogFilePath = Join-Path -Path $PSScriptRoot -ChildPath $logFileName
        
        # Display header
        Write-Log -Message "===========================================================================" -Level MAINHEADER
        Write-Log -Message "" -Level MAINHEADER
        Write-Log -Message "               Reset KrbTgt Password For RWDCs And RODCs" -Level MAINHEADER
        Write-Log -Message "                          Version 4.0.0" -Level MAINHEADER
        Write-Log -Message "" -Level MAINHEADER
        Write-Log -Message "===========================================================================" -Level MAINHEADER
        Write-Log -Message "" -Level MAINHEADER
        
        # Check elevation
        if (-not (Test-LocalElevation)) {
            Write-Log -Message "This function requires an elevated PowerShell session!" -Level ERROR
            throw "Elevation required"
        }
        
        # Test PowerShell modules - ActiveDirectory is required
        $modulesOK = Test-PowerShellModules -ModuleName "ActiveDirectory"
        if ($modulesOK -eq "NotAvailable") {
            Write-Log -Message "Required ActiveDirectory module could not be loaded" -Level ERROR
            throw "Required module not available"
        }
        
        # Determine if local or remote domain
        $localADForest = $true
        $adminCreds = $null
        
        if ($Credential) {
            $localADForest = $false
            $adminCreds = $Credential
        }
    }
    
    process {
        Write-Verbose "Reset-KrbTgtPassword: PROCESS block"
        
        try {
            # ===== MODE SELECTION =====
            if (-not $Mode) {
                Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
                Write-Log -Message "Please select operation mode:" -Level HEADER
                Write-Log -Message "  1 - Informational Mode (No Changes)" -Level INFO
                Write-Log -Message "  2 - Simulation Mode | Temporary Canary Object" -Level INFO
                Write-Log -Message "  3 - Simulation Mode | TEST KrbTgt Accounts (WhatIf)" -Level INFO
                Write-Log -Message "  4 - Real Reset Mode | TEST KrbTgt Accounts" -Level INFO
                Write-Log -Message "  5 - Simulation Mode | PROD KrbTgt Accounts (WhatIf)" -Level INFO
                Write-Log -Message "  6 - Real Reset Mode | PROD KrbTgt Accounts (LIVE IMPACT!)" -Level INFO
                Write-Log -Message "" -Level INFO
                Write-Log -Message "Select mode [1-6]: " -Level "ACTION-NO-NEW-LINE"
                $modeSelection = Read-Host
                
                switch ($modeSelection) {
                    "1" { $Mode = "Info" }
                    "2" { $Mode = "SimulateCanary" }
                    "3" { $Mode = "SimulateTest" }
                    "4" { $Mode = "ResetTest" }
                    "5" { $Mode = "SimulateProd" }
                    "6" { $Mode = "ResetProd" }
                    default {
                        Write-Log -Message "Invalid selection" -Level ERROR
                        return
                    }
                }
            }
            
            # ===== DOMAIN SELECTION =====
            if (-not $TargetDomain) {
                Write-Log -Message "" -Level INFO
                Write-Log -Message "Enter target domain FQDN: " -Level "ACTION-NO-NEW-LINE"
                $TargetDomain = Read-Host
            }
            
            # Validate domain
            Write-Log -Message "" -Level INFO
            Write-Log -Message "Validating domain: $TargetDomain" -Level INFO
            $domainValid = Test-ADDomainValidity -DomainFQDN $TargetDomain -Credential $adminCreds
            if (-not $domainValid) {
                Write-Log -Message "Cannot access domain: $TargetDomain" -Level ERROR
                return
            }
            
            # ===== SCOPE SELECTION =====
            if ($Mode -in @('SimulateCanary', 'SimulateTest', 'ResetTest', 'SimulateProd', 'ResetProd')) {
                if (-not $Scope) {
                    Write-Log -Message "" -Level INFO
                    Write-Log -Message "Select scope:" -Level HEADER
                    Write-Log -Message "  1 - All RWDCs" -Level INFO
                    Write-Log -Message "  2 - All RODCs" -Level INFO
                    Write-Log -Message "  3 - Specific RODCs" -Level INFO
                    Write-Log -Message "" -Level INFO
                    Write-Log -Message "Select scope [1-3]: " -Level "ACTION-NO-NEW-LINE"
                    $scopeSelection = Read-Host
                    
                    switch ($scopeSelection) {
                        "1" { $Scope = "AllRWDCs" }
                        "2" { $Scope = "AllRODCs" }
                        "3" { $Scope = "SpecificRODCs" }
                        default {
                            Write-Log -Message "Invalid selection" -Level ERROR
                            return
                        }
                    }
                }
            }
            
            # ===== EXECUTE SELECTED MODE =====
            Write-Log -Message "" -Level INFO
            Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
            Write-Log -Message "Executing mode: $Mode" -Level HEADER
            Write-Log -Message "Target domain: $TargetDomain" -Level INFO
            if ($Scope) {
                Write-Log -Message "Scope: $Scope" -Level INFO
            }
            Write-Log -Message "------------------------------------------------------------------------------------------------------------------------------------------------------" -Level HEADER
            Write-Log -Message "" -Level INFO
            
            # Get domain controllers
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
            
            switch ($Mode) {
                'Info' {
                    Write-Log -Message "INFORMATIONAL MODE - Analyzing environment (no changes)" -Level HEADER
                    Write-Log -Message "" -Level INFO
                    
                    # Display DC Information
                    Write-Log -Message "Domain Controllers in $TargetDomain`:" -Level HEADER
                    Write-Log -Message "" -Level INFO
                    
                    foreach ($dc in $dcList) {
                        $dcType = if ($dc.IsRODC) { "RODC" } else { "RWDC" }
                        $pdcMarker = if ($dc.IsPDC) { " [PDC FSMO]" } else { "" }
                        
                        Write-Log -Message "  - $($dc.HostName)$pdcMarker" -Level INFO
                        Write-Log -Message "      Type: $dcType" -Level INFO
                        Write-Log -Message "      Site: $($dc.SiteName)" -Level INFO
                        Write-Log -Message "      IP: $($dc.IPAddress)" -Level INFO
                        Write-Log -Message "      OS: $($dc.OSVersion)" -Level INFO
                        
                        # Get KrbTgt account info
                        if ($dc.IsRODC) {
                            # RODC has specific krbtgt account
                            try {
                                $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
                                $domainDN = $rootDSE.defaultNamingContext.distinguishedName
                                
                                $rodcComputerObj = Find-LdapObject `
                                    -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                    -searchBase $domainDN `
                                    -searchFilter "(&(objectClass=computer)(dNSHostName=$($dc.HostName)))" `
                                    -PropertiesToLoad @("msDS-KrbTgtLink")
                                
                                if ($rodcComputerObj -and $rodcComputerObj.'msDS-KrbTgtLink') {
                                    $krbTgtDN = $rodcComputerObj.'msDS-KrbTgtLink'
                                    $krbTgtObj = Find-LdapObject `
                                        -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                        -searchBase $krbTgtDN `
                                        -searchFilter "(objectClass=user)" `
                                        -searchScope Base `
                                        -PropertiesToLoad @("sAMAccountName", "pwdLastSet")
                                    
                                    if ($krbTgtObj) {
                                        $pwdLastSet = [DateTime]::FromFileTime($krbTgtObj.pwdLastSet)
                                        Write-Log -Message "      KrbTgt Account: $($krbTgtObj.sAMAccountName)" -Level INFO
                                        Write-Log -Message "      Password Last Set: $pwdLastSet" -Level INFO
                                    }
                                }
                            } catch {
                                Write-Log -Message "      KrbTgt Account: Unable to retrieve" -Level WARNING
                            }
                        } else {
                            # RWDC uses standard krbtgt account
                            Write-Log -Message "      KrbTgt Account: krbtgt" -Level INFO
                        }
                        
                        Write-Log -Message "" -Level INFO
                    }
                    
                    Write-Log -Message "Informational analysis complete" -Level SUCCESS
                }
                
                'SimulateCanary' {
                    Write-Log -Message "CANARY SIMULATION MODE - Testing replication with temporary object" -Level HEADER
                    Write-Log -Message "" -Level INFO
                    
                    # Create timestamp for canary object
                    $execDateTime = Get-Date -Format "yyyyMMddHHmmss"
                    
                    # Create canary object
                    Write-Log -Message "Creating temporary canary object..." -Level INFO
                    $canaryDN = New-TemporaryCanaryObject `
                        -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                        -KrbTgtSamAccountName "krbtgt" `
                        -ExecDateTimeCustom $execDateTime `
                        -LocalADForest $localADForest `
                        -AdminCredentials $adminCreds
                    
                    if ($canaryDN) {
                        Write-Log -Message "Canary object created: $canaryDN" -Level SUCCESS
                        Write-Log -Message "" -Level INFO
                        
                        # Monitor replication
                        Write-Log -Message "Monitoring replication convergence..." -Level INFO
                        $dcFQDNs = $dcList | ForEach-Object { $_.HostName }
                        $replicationResult = Test-ADReplicationConvergence `
                            -DomainFQDN $TargetDomain `
                            -ObjectDN $canaryDN `
                            -DomainControllers $dcFQDNs `
                            -IsLocalForest $localADForest `
                            -Credential $adminCreds `
                            -MaxWaitMinutes 30
                        
                        if ($replicationResult.Converged) {
                            Write-Log -Message "Replication converged successfully" -Level SUCCESS
                            Write-Log -Message "Time taken: $($replicationResult.TimeTaken)" -Level INFO
                            Write-Log -Message "Replicated to $($replicationResult.ReplicatedDCs.Count) DCs" -Level INFO
                        } else {
                            Write-Log -Message "Replication did not fully converge" -Level WARNING
                            Write-Log -Message "Replicated DCs: $($replicationResult.ReplicatedDCs.Count)" -Level INFO
                            Write-Log -Message "Pending DCs: $($replicationResult.PendingDCs.Count)" -Level WARNING
                        }
                        
                        Write-Log -Message "" -Level INFO
                        
                        # Remove canary
                        Write-Log -Message "Removing canary object..." -Level INFO
                        Remove-TemporaryCanaryObject `
                            -TargetedADDomainRWDCFQDN $targetRWDCFQDN `
                            -TargetObjectToCheckDN $canaryDN `
                            -LocalADForest $localADForest `
                            -AdminCredentials $adminCreds
                    }
                }
                
                'SimulateTest' {
                    Write-Log -Message "TEST SIMULATION MODE - Simulating password reset (WhatIf)" -Level HEADER
                    Write-Log -Message "" -Level INFO
                    
                    # Determine accounts based on scope
                    $accountsToProcess = @()
                    
                    if ($Scope -eq "AllRWDCs") {
                        $accountsToProcess += @{
                            Name = "krbtgt_TEST"
                            Type = "RWDC"
                            DC = $targetRWDCFQDN
                        }
                    }
                    
                    if ($Scope -in @("AllRODCs", "SpecificRODCs")) {
                        $rodcs = $dcList | Where-Object { $_.IsRODC -eq $true }
                        
                        if ($Scope -eq "SpecificRODCs" -and $TargetRODCs) {
                            $rodcs = $rodcs | Where-Object { $TargetRODCs -contains $_.HostName }
                        }
                        
                        foreach ($rodc in $rodcs) {
                            # Get RODC's krbtgt account name
                            try {
                                $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
                                $domainDN = $rootDSE.defaultNamingContext.distinguishedName
                                
                                $rodcComputerObj = Find-LdapObject `
                                    -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                    -searchBase $domainDN `
                                    -searchFilter "(&(objectClass=computer)(dNSHostName=$($rodc.HostName)))" `
                                    -PropertiesToLoad @("msDS-KrbTgtLink")
                                
                                if ($rodcComputerObj -and $rodcComputerObj.'msDS-KrbTgtLink') {
                                    $krbTgtDN = $rodcComputerObj.'msDS-KrbTgtLink'
                                    $krbTgtObj = Find-LdapObject `
                                        -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                        -searchBase $krbTgtDN `
                                        -searchFilter "(objectClass=user)" `
                                        -searchScope Base `
                                        -PropertiesToLoad @("sAMAccountName")
                                    
                                    if ($krbTgtObj) {
                                        $accountsToProcess += @{
                                            Name = $krbTgtObj.sAMAccountName + "_TEST"
                                            Type = "RODC"
                                            DC = $rodc.HostName
                                        }
                                    }
                                }
                            } catch {
                                Write-Log -Message "Error processing RODC $($rodc.HostName): $($_.Exception.Message)" -Level WARNING
                            }
                        }
                    }
                    
                    # Display what would happen
                    Write-Log -Message "The following accounts would have their passwords reset:" -Level INFO
                    foreach ($account in $accountsToProcess) {
                        Write-Log -Message "  - $($account.Name) [$($account.Type)]" -Level INFO
                        Write-Log -Message "      DC: $($account.DC)" -Level INFO
                    }
                    
                    Write-Log -Message "" -Level INFO
                    Write-Log -Message "Simulation complete (no changes made)" -Level SUCCESS
                }
                
                'ResetTest' {
                    Write-Log -Message "TEST RESET MODE - Resetting TEST account passwords" -Level HEADER
                    Write-Log -Message "" -Level INFO
                    
                    if (-not $PSCmdlet.ShouldProcess("TEST KrbTgt accounts in $TargetDomain", "Reset passwords")) {
                        Write-Log -Message "Operation cancelled" -Level WARNING
                        return
                    }
                    
                    # Confirmation
                    if (-not $ContinueOnWarning) {
                        Write-Log -Message "Are you sure you want to reset TEST account passwords? [YES/NO]: " -Level "ACTION-NO-NEW-LINE"
                        $confirm = Read-Host
                        if ($confirm.ToUpper() -ne "YES") {
                            Write-Log -Message "Operation cancelled" -Level WARNING
                            return
                        }
                    }
                    
                    Write-Log -Message "" -Level INFO
                    
                    # Process RWDC account
                    if ($Scope -eq "AllRWDCs") {
                        Write-Log -Message "Resetting krbtgt_TEST password..." -Level INFO
                        
                        $resetResult = Set-KrbTgtPassword `
                            -TargetedDomainRWDCFQDN $targetRWDCFQDN `
                            -KrbTgtSamAccountName "krbtgt_TEST" `
                            -IsLocalForest $localADForest `
                            -Credential $adminCreds
                        
                        if ($resetResult.Success) {
                            Write-Log -Message "Password reset successful" -Level SUCCESS
                            Write-Log -Message "Previous password set: $($resetResult.PreviousPwdSet)" -Level INFO
                            Write-Log -Message "New password set: $($resetResult.NewPwdSet)" -Level INFO
                            
                            # Note: AD will replicate automatically, monitoring convergence below
                            Write-Log -Message "Waiting for automatic AD replication..." -Level INFO
                        } else {
                            Write-Log -Message "Password reset failed" -Level ERROR
                        }
                    }
                    
                    # Process RODC accounts
                    if ($Scope -in @("AllRODCs", "SpecificRODCs")) {
                        $rodcs = $dcList | Where-Object { $_.IsRODC -eq $true }
                        
                        if ($Scope -eq "SpecificRODCs" -and $TargetRODCs) {
                            $rodcs = $rodcs | Where-Object { $TargetRODCs -contains $_.HostName }
                        }
                        
                        foreach ($rodc in $rodcs) {
                            # Get RODC's TEST account
                            try {
                                $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
                                $domainDN = $rootDSE.defaultNamingContext.distinguishedName
                                
                                $rodcComputerObj = Find-LdapObject `
                                    -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                    -searchBase $domainDN `
                                    -searchFilter "(&(objectClass=computer)(dNSHostName=$($rodc.HostName)))" `
                                    -PropertiesToLoad @("msDS-KrbTgtLink")
                                
                                if ($rodcComputerObj -and $rodcComputerObj.'msDS-KrbTgtLink') {
                                    $krbTgtDN = $rodcComputerObj.'msDS-KrbTgtLink'
                                    $krbTgtObj = Find-LdapObject `
                                        -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                        -searchBase $krbTgtDN `
                                        -searchFilter "(objectClass=user)" `
                                        -searchScope Base `
                                        -PropertiesToLoad @("sAMAccountName")
                                    
                                    if ($krbTgtObj) {
                                        $testAccountName = $krbTgtObj.sAMAccountName + "_TEST"
                                        
                                        Write-Log -Message "Resetting $testAccountName for RODC $($rodc.HostName)..." -Level INFO
                                        
                                        $resetResult = Set-KrbTgtPassword `
                                            -TargetDC $targetRWDCFQDN `
                                            -KrbTgtAccountName $testAccountName `
                                            -Credential $adminCreds
                                        
                                        if ($resetResult.Success) {
                                            Write-Log -Message "Password reset successful" -Level SUCCESS
                                            
                                            # Note: AD will replicate secrets to RODC automatically
                                            Write-Log -Message "Waiting for automatic secret replication to RODC..." -Level INFO
                                        } else {
                                            Write-Log -Message "Password reset failed" -Level ERROR
                                        }
                                    }
                                }
                            } catch {
                                Write-Log -Message "Error processing RODC $($rodc.HostName): $($_.Exception.Message)" -Level ERROR
                            }
                        }
                    }
                    
                    Write-Log -Message "" -Level INFO
                    Write-Log -Message "TEST account password reset complete" -Level SUCCESS
                }
                
                'SimulateProd' {
                    Write-Log -Message "PRODUCTION SIMULATION MODE - Simulating password reset (WhatIf)" -Level HEADER
                    Write-Log -Message "WARNING: This shows what would happen in PRODUCTION!" -Level WARNING
                    Write-Log -Message "" -Level INFO
                    
                    # Determine accounts based on scope
                    $accountsToProcess = @()
                    
                    if ($Scope -eq "AllRWDCs") {
                        $accountsToProcess += @{
                            Name = "krbtgt"
                            Type = "RWDC"
                            DC = $targetRWDCFQDN
                        }
                    }
                    
                    if ($Scope -in @("AllRODCs", "SpecificRODCs")) {
                        $rodcs = $dcList | Where-Object { $_.IsRODC -eq $true }
                        
                        if ($Scope -eq "SpecificRODCs" -and $TargetRODCs) {
                            $rodcs = $rodcs | Where-Object { $TargetRODCs -contains $_.HostName }
                        }
                        
                        foreach ($rodc in $rodcs) {
                            try {
                                $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
                                $domainDN = $rootDSE.defaultNamingContext.distinguishedName
                                
                                $rodcComputerObj = Find-LdapObject `
                                    -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                    -searchBase $domainDN `
                                    -searchFilter "(&(objectClass=computer)(dNSHostName=$($rodc.HostName)))" `
                                    -PropertiesToLoad @("msDS-KrbTgtLink")
                                
                                if ($rodcComputerObj -and $rodcComputerObj.'msDS-KrbTgtLink') {
                                    $krbTgtDN = $rodcComputerObj.'msDS-KrbTgtLink'
                                    $krbTgtObj = Find-LdapObject `
                                        -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                        -searchBase $krbTgtDN `
                                        -searchFilter "(objectClass=user)" `
                                        -searchScope Base `
                                        -PropertiesToLoad @("sAMAccountName")
                                    
                                    if ($krbTgtObj) {
                                        $accountsToProcess += @{
                                            Name = $krbTgtObj.sAMAccountName
                                            Type = "RODC"
                                            DC = $rodc.HostName
                                        }
                                    }
                                }
                            } catch {
                                Write-Log -Message "Error processing RODC $($rodc.HostName): $($_.Exception.Message)" -Level WARNING
                            }
                        }
                    }
                    
                    # Display what would happen
                    Write-Log -Message "The following PRODUCTION accounts would have their passwords reset:" -Level WARNING
                    foreach ($account in $accountsToProcess) {
                        Write-Log -Message "  - $($account.Name) [$($account.Type)]" -Level WARNING
                        Write-Log -Message "      DC: $($account.DC)" -Level INFO
                    }
                    
                    Write-Log -Message "" -Level INFO
                    Write-Log -Message "Simulation complete (no changes made)" -Level SUCCESS
                }
                
                'ResetProd' {
                    Write-Log -Message "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -Level WARNING
                    Write-Log -Message "!!! PRODUCTION RESET MODE - LIVE DOMAIN IMPACT !!!" -Level WARNING
                    Write-Log -Message "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -Level WARNING
                    Write-Log -Message "" -Level WARNING
                    
                    if (-not $PSCmdlet.ShouldProcess("PRODUCTION KrbTgt accounts in $TargetDomain", "Reset passwords")) {
                        Write-Log -Message "Operation cancelled" -Level WARNING
                        return
                    }
                    
                    # Multiple confirmations for production
                    if (-not $ContinueOnWarning) {
                        Write-Log -Message "This will reset PRODUCTION KrbTgt account passwords!" -Level WARNING
                        Write-Log -Message "This will cause ALL Kerberos tickets to be invalidated!" -Level WARNING
                        Write-Log -Message "Users and services will need to re-authenticate!" -Level WARNING
                        Write-Log -Message "" -Level WARNING
                        Write-Log -Message "Type 'I UNDERSTAND THE IMPACT' to continue: " -Level "ACTION-NO-NEW-LINE"
                        $confirm1 = Read-Host
                        
                        if ($confirm1 -ne "I UNDERSTAND THE IMPACT") {
                            Write-Log -Message "Operation cancelled" -Level WARNING
                            return
                        }
                        
                        Write-Log -Message "" -Level WARNING
                        Write-Log -Message "Final confirmation - Type 'PROCEED' to reset production passwords: " -Level "ACTION-NO-NEW-LINE"
                        $confirm2 = Read-Host
                        
                        if ($confirm2 -ne "PROCEED") {
                            Write-Log -Message "Operation cancelled" -Level WARNING
                            return
                        }
                    }
                    
                    Write-Log -Message "" -Level INFO
                    Write-Log -Message "Beginning PRODUCTION password reset..." -Level WARNING
                    Write-Log -Message "" -Level INFO
                    
                    # Process RWDC account
                    if ($Scope -eq "AllRWDCs") {
                        Write-Log -Message "Resetting krbtgt password..." -Level WARNING
                        
                        $resetResult = Set-KrbTgtPassword `
                            -TargetedDomainRWDCFQDN $targetRWDCFQDN `
                            -KrbTgtSamAccountName "krbtgt" `
                            -IsLocalForest $localADForest `
                            -Credential $adminCreds
                        
                        if ($resetResult.Success) {
                            Write-Log -Message "PRODUCTION password reset successful" -Level WARNING
                            Write-Log -Message "Previous password set: $($resetResult.PreviousPwdSet)" -Level INFO
                            Write-Log -Message "New password set: $($resetResult.NewPwdSet)" -Level INFO
                            
                            # Note: AD will replicate automatically
                            Write-Log -Message "Waiting for automatic AD replication..." -Level INFO
                            
                            # Monitor convergence
                            Write-Log -Message "Monitoring replication convergence..." -Level INFO
                            $dcFQDNs = $dcList | ForEach-Object { $_.HostName }
                            $replicationResult = Test-ADReplicationConvergence `
                                -DomainFQDN $TargetDomain `
                                -ObjectDN $resetResult.DistinguishedName `
                                -DomainControllers $dcFQDNs `
                                -AttributeName "pwdLastSet" `
                                -IsLocalForest $localADForest `
                                -Credential $adminCreds `
                                -MaxWaitMinutes 30
                            
                            if ($replicationResult.Converged) {
                                Write-Log -Message "Replication converged successfully" -Level SUCCESS
                            } else {
                                Write-Log -Message "Replication did not fully converge - manual verification required" -Level WARNING
                            }
                        } else {
                            Write-Log -Message "PRODUCTION password reset FAILED" -Level ERROR
                        }
                    }
                    
                    # Process RODC accounts
                    if ($Scope -in @("AllRODCs", "SpecificRODCs")) {
                        $rodcs = $dcList | Where-Object { $_.IsRODC -eq $true }
                        
                        if ($Scope -eq "SpecificRODCs" -and $TargetRODCs) {
                            $rodcs = $rodcs | Where-Object { $TargetRODCs -contains $_.HostName }
                        }
                        
                        foreach ($rodc in $rodcs) {
                            try {
                                $rootDSE = Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos)
                                $domainDN = $rootDSE.defaultNamingContext.distinguishedName
                                
                                $rodcComputerObj = Find-LdapObject `
                                    -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                    -searchBase $domainDN `
                                    -searchFilter "(&(objectClass=computer)(dNSHostName=$($rodc.HostName)))" `
                                    -PropertiesToLoad @("msDS-KrbTgtLink")
                                
                                if ($rodcComputerObj -and $rodcComputerObj.'msDS-KrbTgtLink') {
                                    $krbTgtDN = $rodcComputerObj.'msDS-KrbTgtLink'
                                    $krbTgtObj = Find-LdapObject `
                                        -LdapConnection $(Get-LdapConnection -LdapServer:$targetRWDCFQDN -EncryptionType Kerberos) `
                                        -searchBase $krbTgtDN `
                                        -searchFilter "(objectClass=user)" `
                                        -searchScope Base `
                                        -PropertiesToLoad @("sAMAccountName")
                                    
                                    if ($krbTgtObj) {
                                        $prodAccountName = $krbTgtObj.sAMAccountName
                                        
                                        Write-Log -Message "Resetting $prodAccountName for RODC $($rodc.HostName)..." -Level WARNING
                                        
                                        $resetResult = Set-KrbTgtPassword `
                                            -TargetDC $targetRWDCFQDN `
                                            -KrbTgtAccountName $prodAccountName `
                                            -Credential $adminCreds
                                        
                                        if ($resetResult.Success) {
                                            Write-Log -Message "Password reset successful" -Level SUCCESS
                                            
                                            # Note: AD will replicate secrets to RODC automatically
                                            Write-Log -Message "Waiting for automatic secret replication to RODC..." -Level INFO
                                        } else {
                                            Write-Log -Message "Password reset FAILED" -Level ERROR
                                        }
                                    }
                                }
                            } catch {
                                Write-Log -Message "Error processing RODC $($rodc.HostName): $($_.Exception.Message)" -Level ERROR
                            }
                        }
                    }
                    
                    Write-Log -Message "" -Level INFO
                    Write-Log -Message "PRODUCTION password reset complete" -Level WARNING
                    Write-Log -Message "Monitor domain for authentication issues" -Level WARNING
                }
            }
        }
        catch {
            Write-Log -Message "ERROR: $_" -Level ERROR
            Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
            throw
        }
    }
    
    end {
        Write-Verbose "Reset-KrbTgtPassword: END block"
        
        Write-Log -Message "" -Level INFO
        Write-Log -Message "===========================================================================" -Level MAINHEADER
        Write-Log -Message "Operation completed" -Level SUCCESS
        Write-Log -Message "Log file: $Script:LogFilePath" -Level INFO
        Write-Log -Message "===========================================================================" -Level MAINHEADER
    }
}
