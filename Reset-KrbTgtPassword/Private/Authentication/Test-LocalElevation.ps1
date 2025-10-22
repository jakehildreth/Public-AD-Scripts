Function Test-LocalElevation {
<#
.SYNOPSIS
    Checks if the PowerShell session is running with elevated (administrator) privileges.

.DESCRIPTION
    Determines whether the current PowerShell process is running in an elevated 
    context by comparing the process owner SID with the process user SID.
    When these SIDs are equal, the process is NOT elevated.
    When different, the process IS elevated.

.OUTPUTS
    String - Returns "ELEVATED" if running with elevated privileges, "NOT-ELEVATED" otherwise.

.EXAMPLE
    $elevationStatus = Test-LocalElevation
    if ($elevationStatus -eq "NOT-ELEVATED") {
        Write-Warning "This script requires elevated privileges. Please run as Administrator."
        exit
    }
    
    Checks elevation status and exits if not elevated.

.EXAMPLE
    if ((Test-LocalElevation) -eq "ELEVATED") {
        # Perform administrative tasks
        Write-Host "Running with administrator privileges"
    }
    
    Performs tasks only if running elevated.

.NOTES
    Original function: checkLocalElevationStatus
    Extracted from: Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1 (lines 3159-3174)
    Author: Jorge de Almeida Pinto
    Version: 4.0.0
    
    This function is critical for ensuring the script has necessary permissions
    to perform KrbTgt password resets and other AD operations.
#>
    [CmdletBinding()]
    [OutputType([string])]
    Param()

    Process {
        Try {
            # Determine Current User
            $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()

            # Check The Process Owner SID And The User SID And Compare
            $processOwnerSid = $currentUser.Owner.Value
            $processUserSid = $currentUser.User.Value

            # When Equal, Not Elevated. When Different Elevated
            If ($processOwnerSid -eq $processUserSid) {
                Return "NOT-ELEVATED"
            } Else {
                Return "ELEVATED"
            }
        }
        Catch {
            Write-Log -Message "ERROR: Failed to check elevation status: $($_.Exception.Message)" -Level ERROR
            # Default to NOT-ELEVATED for safety
            Return "NOT-ELEVATED"
        }
    }
}
