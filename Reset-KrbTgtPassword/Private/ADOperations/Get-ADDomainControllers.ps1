Function Get-ADDomainControllers {
<#
.SYNOPSIS
    Retrieves a list of domain controllers for a given domain.

.DESCRIPTION
    Queries Active Directory to get all domain controllers (RWDCs and optionally RODCs)
    for a specified domain. Returns detailed information about each DC.

.PARAMETER DomainFQDN
    The FQDN of the domain to query.

.PARAMETER IncludeRODCs
    If specified, includes Read-Only Domain Controllers in the results.

.PARAMETER Credential
    Optional PSCredential for remote domain authentication.

.OUTPUTS
    Array of PSCustomObjects containing DC information.

.EXAMPLE
    $dcs = Get-ADDomainControllers -DomainFQDN "contoso.com"
    $dcs | ForEach-Object { Write-Host "DC: $($_.Name)" }

.NOTES
    Version: 4.0.0
    Uses System.DirectoryServices.ActiveDirectory for DC discovery.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$DomainFQDN,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeRODCs,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null
    )

    Process {
        Try {
            Write-Log -Message "Retrieving domain controllers for '$DomainFQDN'..." -Level INFO

            # Create directory context
            $domainContext = $null
            if ($Credential) {
                $domainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(
                    "Domain",
                    $DomainFQDN,
                    $Credential.UserName,
                    $Credential.GetNetworkCredential().Password
                )
            } else {
                $domainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $DomainFQDN)
            }

            # Get domain object
            $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext)

            # Get all domain controllers
            $allDCs = @()

            # Get RWDCs
            foreach ($dc in $domain.DomainControllers) {
                $allDCs += [PSCustomObject]@{
                    Name = $dc.Name
                    SiteName = $dc.SiteName
                    IPAddress = $dc.IPAddress
                    IsReadOnly = $false
                    OSVersion = $dc.OSVersion
                    Roles = @($dc.Roles)
                }
            }

            # Get RODCs if requested
            if ($IncludeRODCs) {
                foreach ($rodc in $domain.FindAllDiscoverableReadOnlyDomainControllers()) {
                    $allDCs += [PSCustomObject]@{
                        Name = $rodc.Name
                        SiteName = $rodc.SiteName
                        IPAddress = $rodc.IPAddress
                        IsReadOnly = $true
                        OSVersion = $rodc.OSVersion
                        Roles = @()
                    }
                }
            }

            Write-Log -Message "Found $($allDCs.Count) domain controller(s)" -Level SUCCESS
            Return $allDCs
        }
        Catch {
            Write-Log -Message "ERROR: Failed to retrieve domain controllers: $($_.Exception.Message)" -Level ERROR
            Return @()
        }
    }
}
