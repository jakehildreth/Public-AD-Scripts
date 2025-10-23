Function Get-KrbtgtAccountInfo {
<#
.SYNOPSIS
    Retrieves information about a Krbtgt account.

.DESCRIPTION
    Queries AD for a Krbtgt account and returns key properties including:
    - Distinguished Name
    - sAMAccountName
    - Password Last Set
    - Object metadata (originating DC, version, etc.)

.PARAMETER DomainRWDCFQDN
    The FQDN of a domain controller to query.

.PARAMETER SamAccountName
    The sAMAccountName of the Krbtgt account (e.g., "krbtgt" or "krbtgt_12345").

.PARAMETER IsLocalForest
    Boolean indicating if the target forest is the local forest.

.PARAMETER Credential
    Optional PSCredential for remote forest authentication.

.OUTPUTS
    PSCustomObject with account properties or $null if not found.

.EXAMPLE
    $info = Get-KrbtgtAccountInfo -DomainRWDCFQDN "dc01.contoso.com" -SamAccountName "krbtgt" -IsLocalForest $true
    Write-Host "Last password set: $($info.PwdLastSet)"

.NOTES
    Version: 4.0.0
    Uses LDAP queries via S.DS.P module for compatibility.
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$DomainRWDCFQDN,

        [Parameter(Mandatory = $true)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $true)]
        [bool]$IsLocalForest,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null
    )

    Process {
        Try {
            # Get LDAP connection
            $ldapParams = @{
                LdapServer = $DomainRWDCFQDN
                EncryptionType = 'Kerberos'
            }
            if ($Credential) {
                $ldapParams['Credential'] = $Credential
            }
            $ldapConn = Get-LdapConnection @ldapParams

            # Get search base
            $searchBase = (Get-RootDSE -LdapConnection $ldapConn).defaultNamingContext.distinguishedName

            # Query for account
            $account = Find-LdapObject -LdapConnection $ldapConn `
                -searchBase $searchBase `
                -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$SamAccountName))" `
                -PropertiesToLoad @("distinguishedName", "sAMAccountName", "pwdLastSet", "objectGuid")

            if ($account) {
                # Convert pwdLastSet
                $pwdLastSet = $null
                if ($account.pwdLastSet) {
                    $pwdLastSet = [datetime]::fromfiletime($account.pwdLastSet)
                }

                Return [PSCustomObject]@{
                    DistinguishedName = $account.distinguishedName
                    SamAccountName = $account.sAMAccountName
                    PwdLastSet = $pwdLastSet
                    ObjectGuid = $account.objectGuid
                }
            }

            Return $null
        }
        Catch {
            Write-Log -Message "ERROR: Failed to retrieve Krbtgt account info: $($_.Exception.Message)" -Level ERROR
            Return $null
        }
    }
}
