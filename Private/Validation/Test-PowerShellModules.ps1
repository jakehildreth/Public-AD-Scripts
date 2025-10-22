Function Test-PowerShellModules {
<#
.SYNOPSIS
    Loads or validates availability of required PowerShell modules.

.DESCRIPTION
    Checks if a specified PowerShell module is available and loaded. If not loaded,
    attempts to import it. If not available, optionally prompts to install it.
    
    For the GroupPolicy module, this will attempt to install the GPMC Windows Feature
    if the user confirms installation.

.PARAMETER ModuleName
    The name of the PowerShell module to load or verify.

.PARAMETER IgnoreRemote
    If $true, suppresses log messages about remote operations.

.OUTPUTS
    String - Returns one of the following:
    - "AlreadyLoaded": Module was already loaded
    - "HasBeenLoaded": Module was successfully imported
    - "NotAvailable": Module is not available and user declined installation

.EXAMPLE
    $result = Test-PowerShellModules -ModuleName "GroupPolicy"
    if ($result -eq "NotAvailable") {
        Write-Warning "GroupPolicy module is required but not available"
        exit
    }
    
    Loads the GroupPolicy module and exits if unavailable.

.EXAMPLE
    Test-PowerShellModules -ModuleName "ActiveDirectory" -IgnoreRemote $true
    
    Loads the ActiveDirectory module without logging remote operation messages.

.NOTES
    Original function: loadPoSHModules
    Extracted from: Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 (lines 3120-3154)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    This function is interactive and may prompt the user for installation confirmation.
#>
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [bool]$IgnoreRemote = $false
    )

    Process {
        $retValue = $null

        Try {
            # Check if module is already loaded
            If (@(Get-Module | Where-Object{$_.Name -eq $ModuleName}).Count -eq 0) {
                # Module not loaded, check if available
                If (@(Get-Module -ListAvailable | Where-Object{$_.Name -eq $ModuleName}).Count -ne 0) {
                    # Module available, import it
                    Import-Module $ModuleName
                    Write-Log -Message "PoSH Module '$ModuleName' Has Been Loaded..." -Level SUCCESS
                    $retValue = "HasBeenLoaded"
                } Else {
                    # Module not available
                    Write-Log -Message "PoSH Module '$ModuleName' Is Not Available To Load..." -Level ERROR
                    Write-Log -Message "The PoSH Module '$ModuleName' Is Required For This Script To Work..." -Level REMARK
                    
                    $confirmInstallPoshModuleYESNO = $null
                    $confirmInstallPoshModuleYESNO = Read-Host "Would You Like To Install The PoSH Module '$ModuleName' NOW? [Yes|No]"
                    
                    If ($confirmInstallPoshModuleYESNO.ToUpper() -eq "YES" -Or $confirmInstallPoshModuleYESNO.ToUpper() -eq "Y") {
                        # User confirmed installation
                        If ($ModuleName -eq "GroupPolicy") {
                            Write-Log -Message "Installing The Windows Feature 'GPMC' For The PoSH Module '$ModuleName'..." -Level REMARK
                            Add-WindowsFeature -Name "GPMC" -IncludeAllSubFeature | Out-Null
                        }
                        
                        # Check if module is now available after installation
                        If (@(Get-Module -ListAvailable | Where-Object{$_.Name -eq $ModuleName}).Count -ne 0) {
                            Import-Module $ModuleName
                            Write-Log -Message "PoSH Module '$ModuleName' Has Been Loaded..." -Level SUCCESS
                            $retValue = "HasBeenLoaded"
                        } Else {
                            Write-Log -Message "Aborting Script..." -Level ERROR
                            $retValue = "NotAvailable"
                        }
                    } Else {
                        # User declined installation
                        Write-Log -Message "Aborting Script..." -Level ERROR
                        $retValue = "NotAvailable"
                    }
                }
            } Else {
                # Module already loaded
                Write-Log -Message "PoSH Module '$ModuleName' Already Loaded..." -Level SUCCESS
                $retValue = "AlreadyLoaded"
            }
            
            Return $retValue
        }
        Catch {
            Write-Log -Message "ERROR: Failed to load PowerShell module '$ModuleName': $($_.Exception.Message)" -Level ERROR
            Return "NotAvailable"
        }
    }
}
