Function Request-AdminCredentials {
<#
.SYNOPSIS
    Prompts the user for administrative credentials.

.DESCRIPTION
    Interactively requests administrative credentials from the user. This function
    prompts for both username and password, ensuring neither is empty. The credentials
    are returned as a PSCredential object suitable for use with AD operations.
    
    This is typically used when the script needs to operate in a different AD forest
    or when elevated permissions are required beyond the current user's context.

.OUTPUTS
    PSCredential - A credential object containing the provided username and password.

.EXAMPLE
    $adminCreds = Request-AdminCredentials
    
    Prompts for admin credentials and stores them in $adminCreds variable.

.EXAMPLE
    $creds = Request-AdminCredentials
    Get-LdapConnection -LdapServer "dc.domain.com" -Credential $creds
    
    Requests credentials and uses them to establish an LDAP connection.

.NOTES
    Original function: requestForAdminCreds
    Extracted from: Reset-Krbtgt-Password-For-RWDCs-And-RODCs.ps1 (lines 3185-3208)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    Security Note: The password is temporarily converted to plain text during 
    PSCredential creation. This is necessary for the credential object construction
    but the plain text version is not persisted.
#>
    [CmdletBinding()]
    [OutputType([PSCredential])]
    Param()

    Process {
        Try {
            # Ask For The Remote Credentials
            $adminUserAccount = $null
            Do {
                Write-Log -Message "Please provide an account (<DOMAIN FQDN>\<ACCOUNT>) that is a member of the 'Administrators' group in every AD domain of the specified AD forest: " -Level ACTION-NO-NEW-LINE
                $adminUserAccount = Read-Host
            } Until ($adminUserAccount -ne "" -And $null -ne $adminUserAccount)

            # Ask For The Corresponding Password
            $adminUserPasswordString = $null
            Do {
                Write-Log -Message "Please provide the corresponding password of that admin account: " -Level ACTION-NO-NEW-LINE
                [System.Security.SecureString]$adminUserPasswordSecureString = Read-Host -AsSecureString -ErrorAction SilentlyContinue
            } Until ($adminUserPasswordSecureString.Length -gt 0)
            
            # Convert secure string to credential object
            # Note: Temporary conversion to plain text is required for PSCredential creation
            [string]$adminUserPasswordString = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminUserPasswordSecureString))
            $secureAdminUserPassword = ConvertTo-SecureString $adminUserPasswordString -AsPlainText -Force
            
            # Create and return credential object
            $adminCrds = New-Object System.Management.Automation.PSCredential $adminUserAccount, $secureAdminUserPassword

            Write-Log -Message "Successfully created credential object for user: $adminUserAccount" -Level SUCCESS
            
            Return $adminCrds
        }
        Catch {
            Write-Log -Message "ERROR: Failed to request admin credentials: $($_.Exception.Message)" -Level ERROR
            Throw
        }
    }
}
