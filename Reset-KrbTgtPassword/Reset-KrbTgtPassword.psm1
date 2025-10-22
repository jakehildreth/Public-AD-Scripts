#
# Root module file for Reset-KrbTgtPassword
#
# This module provides comprehensive KrbTgt password reset capabilities for Active Directory
#

#Requires -Version 5.1
# Note: GroupPolicy module is required for full functionality
# It will be checked at runtime by individual functions

# Module-scoped variables
$Script:LogFilePath = $null
$Script:LdapConnection = $null
$Script:ModuleRoot = $PSScriptRoot

# Import S.DS.P LDAP functions (embedded module)
Write-Verbose "Loading S.DS.P LDAP module..."
Get-ChildItem -Path "$PSScriptRoot\Private\LDAP\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Loaded LDAP function: $($_.Name)"
    }
    catch {
        Write-Error "Failed to import LDAP function $($_.Name): $_"
    }
}

# Import private utility functions
Write-Verbose "Loading private utility functions..."
Get-ChildItem -Path "$PSScriptRoot\Private\Utilities\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Loaded utility: $($_.Name)"
    }
    catch {
        Write-Error "Failed to import utility $($_.Name): $_"
    }
}

# Import private authentication functions
Write-Verbose "Loading private authentication functions..."
Get-ChildItem -Path "$PSScriptRoot\Private\Authentication\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Loaded authentication function: $($_.Name)"
    }
    catch {
        Write-Error "Failed to import authentication function $($_.Name): $_"
    }
}

# Import private validation functions
Write-Verbose "Loading private validation functions..."
Get-ChildItem -Path "$PSScriptRoot\Private\Validation\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Loaded validation function: $($_.Name)"
    }
    catch {
        Write-Error "Failed to import validation function $($_.Name): $_"
    }
}

# Import private AD operations functions
Write-Verbose "Loading private AD operations functions..."
Get-ChildItem -Path "$PSScriptRoot\Private\ADOperations\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Loaded AD operation: $($_.Name)"
    }
    catch {
        Write-Error "Failed to import AD operation $($_.Name): $_"
    }
}

# Import private test object functions
Write-Verbose "Loading private test object functions..."
Get-ChildItem -Path "$PSScriptRoot\Private\TestObjects\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Loaded test object function: $($_.Name)"
    }
    catch {
        Write-Error "Failed to import test object function $($_.Name): $_"
    }
}

# Import public functions (exported)
Write-Verbose "Loading public functions..."
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Loaded public function: $($_.Name)"
    }
    catch {
        Write-Error "Failed to import public function $($_.Name): $_"
    }
}

# Export only public functions
Export-ModuleMember -Function @(
    'Reset-KrbTgtPassword',
    'New-TestKrbTgtAccount',
    'Remove-TestKrbTgtAccount'
)

Write-Verbose "Reset-KrbTgtPassword module loaded successfully"
