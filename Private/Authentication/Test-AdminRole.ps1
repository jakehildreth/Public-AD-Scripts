Function Test-AdminRole {
<#
.SYNOPSIS
    Tests if the current user has the specified administrator role.

.DESCRIPTION
    Checks whether the current user's security principal is in the specified 
    Windows administrator role. This is used to verify administrative permissions
    before performing sensitive operations.

.PARAMETER AdminRole
    The administrator role to test for. Can be a string representing a built-in 
    role (e.g., "Administrators") or a SecurityIdentifier object.

.OUTPUTS
    Boolean - $true if the user is in the specified role, $false otherwise.

.EXAMPLE
    Test-AdminRole -AdminRole "Administrators"
    
    Tests if the current user is a member of the local Administrators group.

.EXAMPLE
    Test-AdminRole -AdminRole ([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    Tests if the current user has administrator privileges using the built-in role enum.

.NOTES
    Original function: testAdminRole
    Extracted from: Reset-Krbtgt-Password-For-RWDCs-And-RODCs.ps1 (lines 3176-3183)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
#>
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $AdminRole
    )

    Process {
        Try {
            # Determine Current User
            $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()

            # Check The Current User Is In The Specified Admin Role
            $isInRole = (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($AdminRole)
            
            Return $isInRole
        }
        Catch {
            Write-Log -Message "ERROR: Failed to test admin role: $($_.Exception.Message)" -Level ERROR
            Return $false
        }
    }
}
