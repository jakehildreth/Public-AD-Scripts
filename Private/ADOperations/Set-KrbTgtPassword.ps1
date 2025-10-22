Function Set-KrbTgtPassword {
<#
.SYNOPSIS
    Sets a new password on a KrbTgt account.

.DESCRIPTION
    Resets the password of a specified KrbTgt account on a target RWDC.
    This function:
    1. Retrieves the current password metadata before reset
    2. Generates a new complex password
    3. Sets the new password via LDAP
    4. Retrieves the updated password metadata after reset
    5. Verifies the password was successfully changed
    
    Returns detailed information about the password change including timestamps,
    originating DC, and attribute versions.

.PARAMETER TargetedDomainRWDCFQDN
    The FQDN of the target RWDC where the password will be reset.

.PARAMETER KrbTgtSamAccountName
    The sAMAccountName of the KrbTgt account (e.g., "krbtgt" or "krbtgt_12345").

.PARAMETER IsLocalForest
    Boolean indicating if the target forest is the local forest ($true) or remote ($false).

.PARAMETER Credential
    Optional PSCredential for authentication to remote forests.

.PARAMETER PasswordLength
    The length of the generated password. Default is 64 characters.

.OUTPUTS
    Hashtable with the following keys:
    - Success: Boolean indicating if password was changed
    - DistinguishedName: DN of the KrbTgt account
    - SamAccountName: sAMAccountName of the account
    - PreviousPwdSet: Previous password set time
    - NewPwdSet: New password set time
    - PreviousOriginatingRWDC: Previous originating RWDC
    - NewOriginatingRWDC: New originating RWDC
    - PreviousOriginatingTime: Previous originating time
    - NewOriginatingTime: New originating time
    - PreviousVersion: Previous attribute version
    - NewVersion: New attribute version

.EXAMPLE
    $result = Set-KrbTgtPassword -TargetedDomainRWDCFQDN "dc01.contoso.com" -KrbTgtSamAccountName "krbtgt" -IsLocalForest $true
    if ($result.Success) {
        Write-Host "Password reset successful. New pwd set time: $($result.NewPwdSet)"
    }
    
    Resets the password for the production KrbTgt account.

.EXAMPLE
    $creds = Get-Credential
    $result = Set-KrbTgtPassword -TargetedDomainRWDCFQDN "dc01.fabrikam.com" -KrbTgtSamAccountName "krbtgt_12345" -IsLocalForest $false -Credential $creds
    
    Resets password for an RODC KrbTgt account in a remote forest.

.NOTES
    Original function: setPasswordOfADAccount
    Extracted from: Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 (lines 3431-3615)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    This function performs the actual password reset operation on the KrbTgt account.
    It uses LDAP operations via the S.DS.P module to avoid dependency on ActiveDirectory module.
#>
    [CmdletBinding()]
    [OutputType([hashtable])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetedDomainRWDCFQDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$KrbTgtSamAccountName,

        [Parameter(Mandatory = $true)]
        [bool]$IsLocalForest,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential = $null,

        [Parameter(Mandatory = $false)]
        [ValidateRange(64, 128)]
        [int]$PasswordLength = 64
    )

    Process {
        $result = @{
            Success = $false
            DistinguishedName = $null
            SamAccountName = $KrbTgtSamAccountName
            PreviousPwdSet = $null
            NewPwdSet = $null
            PreviousOriginatingRWDC = $null
            NewOriginatingRWDC = $null
            PreviousOriginatingTime = $null
            NewOriginatingTime = $null
            PreviousVersion = $null
            NewVersion = $null
        }

        Try {
            # Get LDAP connection
            $ldapParams = @{
                LdapServer = $TargetedDomainRWDCFQDN
                EncryptionType = 'Kerberos'
            }
            if ($Credential) {
                $ldapParams['Credential'] = $Credential
            }
            $ldapConn = Get-LdapConnection @ldapParams

            # Get search base
            $searchBase = (Get-RootDSE -LdapConnection $ldapConn).defaultNamingContext.distinguishedName

            # BEFORE: Retrieve KrbTgt object
            Write-Log -Message "Retrieving KrbTgt account '$KrbTgtSamAccountName' from '$TargetedDomainRWDCFQDN'..." -Level INFO
            $krbTgtBefore = Find-LdapObject -LdapConnection $ldapConn `
                -searchBase $searchBase `
                -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$KrbTgtSamAccountName))" `
                -PropertiesToLoad @("distinguishedName", "pwdLastSet")

            if (-not $krbTgtBefore) {
                throw "KrbTgt account '$KrbTgtSamAccountName' not found on '$TargetedDomainRWDCFQDN'"
            }

            $result.DistinguishedName = $krbTgtBefore.distinguishedName
            $result.PreviousPwdSet = Get-Date $([datetime]::fromfiletime($krbTgtBefore.pwdLastSet)) -f "yyyy-MM-dd HH:mm:ss"

            # Get metadata BEFORE
            $metadataBefore = Get-ObjectMetadata -TargetDCFQDN $TargetedDomainRWDCFQDN `
                -ObjectDN $krbTgtBefore.distinguishedName `
                -IsLocalForest $IsLocalForest `
                -Credential $Credential

            $pwdLastSetMetaBefore = $metadataBefore | Where-Object {$_.Name -eq "pwdLastSet"}
            $result.PreviousOriginatingRWDC = if ($pwdLastSetMetaBefore.OriginatingServer) {$pwdLastSetMetaBefore.OriginatingServer} else {"RWDC Demoted"}
            $result.PreviousOriginatingTime = Get-Date $($pwdLastSetMetaBefore.LastOriginatingChangeTime) -f "yyyy-MM-dd HH:mm:ss"
            $result.PreviousVersion = $pwdLastSetMetaBefore.Version

            Write-Log -Message "  --> RWDC: '$TargetedDomainRWDCFQDN'" -Level REMARK
            Write-Log -Message "  --> sAMAccountName: '$KrbTgtSamAccountName'" -Level REMARK
            Write-Log -Message "  --> Distinguished Name: '$($result.DistinguishedName)'" -Level REMARK
            Write-Log -Message "  --> Password Length: '$PasswordLength' characters" -Level REMARK

            # Generate new password
            $newPassword = New-ComplexPassword -Length $PasswordLength
            Write-Log -Message "Generated new complex password" -Level SUCCESS

            # Set the password
            Write-Log -Message "Setting new password on KrbTgt account..." -Level INFO
            $krbTgtObj = [PSCustomObject]@{
                distinguishedName = $krbTgtBefore.distinguishedName
                unicodePwd = $newPassword
            }

            Edit-LdapObject -LdapConnection $ldapConn -Mode Replace -Object $krbTgtObj -BinaryProps unicodePwd

            # AFTER: Retrieve KrbTgt object again
            $krbTgtAfter = Find-LdapObject -LdapConnection $ldapConn `
                -searchBase $searchBase `
                -searchFilter "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$KrbTgtSamAccountName))" `
                -PropertiesToLoad @("distinguishedName", "pwdLastSet")

            $result.NewPwdSet = Get-Date $([datetime]::fromfiletime($krbTgtAfter.pwdLastSet)) -f "yyyy-MM-dd HH:mm:ss"

            # Get metadata AFTER
            $metadataAfter = Get-ObjectMetadata -TargetDCFQDN $TargetedDomainRWDCFQDN `
                -ObjectDN $krbTgtAfter.distinguishedName `
                -IsLocalForest $IsLocalForest `
                -Credential $Credential

            $pwdLastSetMetaAfter = $metadataAfter | Where-Object {$_.Name -eq "pwdLastSet"}
            $result.NewOriginatingRWDC = if ($pwdLastSetMetaAfter.OriginatingServer) {$pwdLastSetMetaAfter.OriginatingServer} else {"RWDC Demoted"}
            $result.NewOriginatingTime = Get-Date $($pwdLastSetMetaAfter.LastOriginatingChangeTime) -f "yyyy-MM-dd HH:mm:ss"
            $result.NewVersion = $pwdLastSetMetaAfter.Version

            # Verify password was changed
            if ($result.NewPwdSet -ne $result.PreviousPwdSet) {
                $result.Success = $true
                Write-Log -Message "" -Level SUCCESS
                Write-Log -Message "  --> Previous Password Set: '$($result.PreviousPwdSet)'" -Level SUCCESS
                Write-Log -Message "  --> New Password Set: '$($result.NewPwdSet)'" -Level SUCCESS
                Write-Log -Message "  --> Previous Originating RWDC: '$($result.PreviousOriginatingRWDC)'" -Level SUCCESS
                Write-Log -Message "  --> New Originating RWDC: '$($result.NewOriginatingRWDC)'" -Level SUCCESS
                Write-Log -Message "  --> Previous Version: '$($result.PreviousVersion)'" -Level SUCCESS
                Write-Log -Message "  --> New Version: '$($result.NewVersion)'" -Level SUCCESS
                Write-Log -Message "" -Level SUCCESS
                Write-Log -Message "  --> Password reset SUCCESSFUL on [$TargetedDomainRWDCFQDN]!" -Level SUCCESS
                Write-Log -Message "" -Level SUCCESS
            } else {
                Write-Log -Message "ERROR: Password was NOT changed. PwdLastSet values are identical." -Level ERROR
            }

            Return $result
        }
        Catch {
            Write-Log -Message "ERROR: Failed to set password for KrbTgt account: $($_.Exception.Message)" -Level ERROR
            Write-Log -Message "Exception Type: $($_.Exception.GetType().FullName)" -Level ERROR
            Write-Log -Message "Script Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
            $result.Success = $false
            Return $result
        }
    }
}
