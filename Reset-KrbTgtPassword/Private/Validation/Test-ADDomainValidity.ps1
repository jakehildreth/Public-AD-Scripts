Function Test-ADDomainValidity {
<#
.SYNOPSIS
    Validates that an AD domain exists and is accessible within a forest.

.DESCRIPTION
    Attempts to retrieve domain information to verify the domain exists and is accessible.
    Returns a hashtable with domain information and accessibility status.
    
    This function uses System.DirectoryServices.ActiveDirectory to retrieve domain
    information without requiring the ActiveDirectory PowerShell module.

.PARAMETER DomainFQDN
    The fully qualified domain name of the AD domain to validate.

.PARAMETER Credential
    Optional PSCredential object for authentication.

.OUTPUTS
    Hashtable with the following keys:
    - IsAvailable: Boolean indicating if domain is accessible
    - Domain: Domain object if available, $null otherwise
    - NearestRWDC: FQDN of nearest writable domain controller if available
    - Error: Error message if domain is not available

.EXAMPLE
    $result = Test-ADDomainValidity -DomainFQDN "contoso.com"
    if ($result.IsAvailable) {
        Write-Host "Domain PDC: $($result.Domain.PdcRoleOwner.Name)"
        Write-Host "Nearest RWDC: $($result.NearestRWDC)"
    } else {
        Write-Error "Domain not available: $($result.Error)"
    }
    
    Validates the contoso.com domain and displays PDC and nearest RWDC.

.EXAMPLE
    $creds = Get-Credential
    $result = Test-ADDomainValidity -DomainFQDN "fabrikam.com" -Credential $creds
    if (-not $result.IsAvailable) {
        Write-Warning "Cannot access domain: $($result.Error)"
    }
    
    Validates a remote domain with credentials.

.NOTES
    Original logic extracted from: Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 (lines 5965-5980)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    This function uses DirectoryContext and System.DirectoryServices.ActiveDirectory
    to avoid dependency on the ActiveDirectory PowerShell module.
#>
    [CmdletBinding()]
    [OutputType([hashtable])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainFQDN,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null
    )

    Process {
        $result = @{
            IsAvailable = $false
            Domain = $null
            NearestRWDC = $null
            Error = $null
        }

        Try {
            Write-Log -Message "Validating AD domain '$DomainFQDN'..." -Level INFO
            
            # Configure locator flags to force rediscovery and find writable DC
            $dcLocatorFlag = [System.DirectoryServices.ActiveDirectory.LocatorOptions]::"ForceRediscovery", "WriteableRequired"
            
            # Create directory context (with or without credentials)
            If ($null -eq $Credential) {
                $adDomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $DomainFQDN)
            } Else {
                $adDomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(
                    "Domain", 
                    $DomainFQDN, 
                    $Credential.UserName, 
                    $Credential.GetNetworkCredential().Password
                )
            }
            
            # Get domain object
            $domainObj = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($adDomainContext)
            
            # Find nearest writable domain controller
            $nearestRWDC = $domainObj.FindDomainController($dcLocatorFlag).Name
            
            # Success
            $result.IsAvailable = $true
            $result.Domain = $domainObj
            $result.NearestRWDC = $nearestRWDC
            
            Write-Log -Message "Domain '$DomainFQDN' is available. Nearest RWDC: $nearestRWDC" -Level SUCCESS
        }
        Catch {
            $result.IsAvailable = $false
            $result.Error = $_.Exception.Message
            
            Write-Log -Message "Domain '$DomainFQDN' is NOT available: $($_.Exception.Message)" -Level ERROR
        }

        Return $result
    }
}
