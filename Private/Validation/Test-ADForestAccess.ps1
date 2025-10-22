Function Test-ADForestAccess {
<#
.SYNOPSIS
    Validates that an AD forest exists and is accessible.

.DESCRIPTION
    Performs comprehensive validation of an Active Directory forest:
    1. Checks DNS resolvability of the forest FQDN
    2. Tests RootDSE connectivity
    3. Attempts to retrieve forest information
    4. Optionally prompts for credentials if initial access fails
    
    Returns a hashtable containing validation results and forest information.

.PARAMETER ForestFQDN
    The fully qualified domain name of the AD forest to validate.

.PARAMETER LocalForestFQDN
    The FQDN of the local forest (for comparison to determine if target is local or remote).

.PARAMETER Credential
    Optional PSCredential object for authentication to remote forests.

.PARAMETER AllowCredentialPrompt
    If $true and initial access fails, prompts the user for credentials.
    If $false, returns failure without prompting.

.OUTPUTS
    Hashtable with the following keys:
    - IsValid: Boolean indicating if forest is resolvable/reachable
    - IsAccessible: Boolean indicating if forest data can be retrieved
    - IsLocal: Boolean indicating if forest is the local forest
    - Forest: Forest object if accessible, $null otherwise
    - Credential: The credential used (may be updated if prompted)

.EXAMPLE
    $result = Test-ADForestAccess -ForestFQDN "contoso.com" -LocalForestFQDN "contoso.com"
    if (-not $result.IsAccessible) {
        Write-Error "Cannot access forest"
        exit
    }
    
    Validates access to the local forest.

.EXAMPLE
    $creds = Get-Credential
    $result = Test-ADForestAccess -ForestFQDN "fabrikam.com" -LocalForestFQDN "contoso.com" -Credential $creds
    if ($result.IsAccessible) {
        $forestInfo = $result.Forest
        Write-Host "Successfully accessed remote forest: $($forestInfo.Name)"
    }
    
    Validates access to a remote forest with credentials.

.NOTES
    Original logic extracted from: Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 (lines 5696-5870)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    This function combines validity checking (DNS/RootDSE) and accessibility checking
    (ability to retrieve forest data) into a single reusable function.
#>
    [CmdletBinding()]
    [OutputType([hashtable])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ForestFQDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LocalForestFQDN,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null,

        [Parameter(Mandatory = $false)]
        [bool]$AllowCredentialPrompt = $false
    )

    Process {
        $result = @{
            IsValid = $false
            IsAccessible = $false
            IsLocal = ($ForestFQDN -eq $LocalForestFQDN)
            Forest = $null
            Credential = $Credential
        }

        $adForestLocation = if ($result.IsLocal) { "Local" } else { "Remote" }

        Try {
            # Step 1: Validate forest exists via DNS resolution
            Write-Log -Message "Checking Resolvability of the specified $adForestLocation AD forest '$ForestFQDN' through DNS..." -Level INFO
            [System.Net.Dns]::GetHostEntry($ForestFQDN) | Out-Null
            $result.IsValid = $true
            Write-Log -Message "Forest '$ForestFQDN' is resolvable through DNS" -Level SUCCESS
        } Catch {
            # DNS failed, try RootDSE
            Try {
                Write-Log -Message "Checking Reachability of the specified $adForestLocation AD forest '$ForestFQDN' through RootDse..." -Level INFO
                Get-RootDSE -LdapConnection $(Get-LdapConnection -LdapServer:$ForestFQDN -EncryptionType Kerberos) -ErrorAction Stop | Out-Null
                $result.IsValid = $true
                Write-Log -Message "Forest '$ForestFQDN' is reachable through RootDse" -Level SUCCESS
            } Catch [System.Security.Authentication.AuthenticationException] {
                # Authentication exception still means forest exists
                $result.IsValid = $true
                Write-Log -Message "Forest '$ForestFQDN' exists but requires authentication" -Level WARNING
            } Catch {
                $result.IsValid = $false
                Write-Log -Message "Forest '$ForestFQDN' is NOT resolvable through DNS and NOT reachable through RootDse" -Level ERROR
                Return $result
            }
        }

        # Step 2: If valid, test accessibility (ability to retrieve forest data)
        If ($result.IsValid) {
            Try {
                Write-Log -Message "Checking Accessibility of the specified AD forest '$ForestFQDN' by retrieving forest data..." -Level INFO
                
                If ($null -eq $Credential) {
                    # Try without credentials first
                    $adForestContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $ForestFQDN)
                    $result.Forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($adForestContext)
                    $result.IsAccessible = $true
                    Write-Log -Message "Forest '$ForestFQDN' is accessible without credentials" -Level SUCCESS
                } Else {
                    # Use provided credentials
                    $adForestContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $ForestFQDN, $Credential.UserName, $Credential.GetNetworkCredential().Password)
                    $result.Forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($adForestContext)
                    $result.IsAccessible = $true
                    Write-Log -Message "Forest '$ForestFQDN' is accessible with provided credentials" -Level SUCCESS
                }
            } Catch {
                # Forest not accessible
                $result.IsAccessible = $false
                Write-Log -Message "Forest '$ForestFQDN' is NOT accessible: $($_.Exception.Message)" -Level WARNING

                # If credential prompt is allowed and we don't have credentials yet, ask for them
                If ($AllowCredentialPrompt -and $null -eq $Credential) {
                    Write-Log -Message "Custom credentials are needed..." -Level WARNING
                    Write-Log -Message "Requesting administrative credentials..." -Level INFO
                    
                    $newCreds = Request-AdminCredentials
                    
                    # Retry with new credentials
                    Try {
                        $adForestContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest", $ForestFQDN, $newCreds.UserName, $newCreds.GetNetworkCredential().Password)
                        $result.Forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($adForestContext)
                        $result.IsAccessible = $true
                        $result.Credential = $newCreds
                        Write-Log -Message "Forest '$ForestFQDN' is accessible with provided credentials" -Level SUCCESS
                    } Catch {
                        $result.IsAccessible = $false
                        Write-Log -Message "Forest '$ForestFQDN' is still NOT accessible even with provided credentials" -Level ERROR
                    }
                }
            }
        }

        Return $result
    }
}
