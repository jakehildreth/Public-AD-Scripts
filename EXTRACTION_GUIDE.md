# Module Extraction Guide

## Overview
This guide explains how to complete the extraction of all functions from the original `Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1` script into the new modular structure.

## Status: Framework Created

### ✅ Completed
- [x] Module directory structure
- [x] Module manifest (`.psd1`)
- [x] Root module file (`.psm1`)
- [x] README with full documentation
- [x] Core utility functions (5 functions)
- [x] Module loading infrastructure

### 📋 Remaining Work
- [ ] Extract remaining utility functions
- [ ] Extract authentication functions
- [ ] Extract validation functions
- [ ] Extract AD operations functions
- [ ] Extract test object functions
- [ ] Extract S.DS.P LDAP module
- [ ] Create public wrapper functions
- [ ] Create configuration template
- [ ] Create help documentation

## Step-by-Step Extraction Process

### Phase 1: Utilities (PARTIAL - 5 of ~10 functions complete)

#### ✅ Already Created:
1. `Write-Log.ps1` - Replaces `Logging` function
2. `Test-PortConnection.ps1` - Replaces `portConnectionCheck` function
3. `New-ComplexPassword.ps1` - Replaces `generateNewComplexPassword` function
4. `Test-PasswordComplexity.ps1` - Replaces `confirmPasswordIsComplex` function
5. `Get-ServerNames.ps1` - Replaces `getServerNames` function

#### ❌ Still Need to Extract:
Create these files in `Private\Utilities\`:

**Send-EmailReport.ps1**
- Extract from: `sendMailMessage` function (lines ~7800-8100)
- Purpose: Sends email with log file, supports S/MIME signing/encryption
- Dependencies: Mail configuration XML

**Initialize-LogFile.ps1**
- Extract from: Log file initialization code (lines ~5500-5550)
- Purpose: Creates and initializes log file path

**Show-Header.ps1**
- Extract from: Header display code (lines ~5000-5100)
- Purpose: Displays script header and version information

**Show-InformationalText.ps1**
- Extract from: Informational text display (lines ~5100-5300)
- Purpose: Shows usage information and recommendations

### Phase 2: Authentication Functions

Create these files in `Private\Authentication\`:

**Test-AdminRole.ps1**
- Extract from: `testAdminRole` function (lines ~900-1100)
- Purpose: Tests if account has required admin permissions (Domain/Enterprise Admins)
- Key logic: Uses IsInRole for group membership testing

**Test-LocalElevation.ps1**
- Extract from: `checkLocalElevationStatus` function (lines ~1100-1200)
- Purpose: Checks if PowerShell session is elevated (UAC)
- Auto-elevates if not running as admin

**Request-AdminCredentials.ps1**
- Extract from: `requestForAdminCreds` function (lines ~1200-1300)
- Purpose: Prompts for admin credentials when needed
- Used for remote forest/domain access

### Phase 3: Validation Functions

Create these files in `Private\Validation\`:

**Test-ADForestAccess.ps1**
- Extract from: Forest validation code (lines ~5600-5700)
- Purpose: Validates AD forest exists and is accessible
- Checks DNS resolution and RootDSE connection

**Test-ADDomainValidity.ps1**
- Extract from: Domain validation code (lines ~5700-5850)
- Purpose: Validates AD domain exists in specified forest
- Retrieves domain information

**Test-PowerShellModules.ps1**
- Extract from: `loadPoSHModules` function (lines ~800-900)
- Purpose: Checks for and loads required PowerShell modules
- Required modules: GroupPolicy

### Phase 4: AD Operations Functions

Create these files in `Private\ADOperations\`:

**Get-KrbTgtAccountInfo.ps1**
- Extract from: KrbTgt account enumeration code (lines ~6000-6200)
- Purpose: Retrieves information about KrbTgt accounts (RWDC and RODC)
- Returns account objects with metadata

**Set-KrbTgtPassword.ps1**
- Extract from: `setPasswordOfADAccount` function (lines ~1400-1600)
- Purpose: Resets password of specified KrbTgt account
- Uses S.DS.P for password reset

**Get-ADDomainControllers.ps1**
- Extract from: DC enumeration code (lines ~5850-6000)
- Purpose: Retrieves list of all DCs in domain with details
- Tests connectivity and reachability

**Get-ObjectMetadata.ps1**
- Extract from: Metadata retrieval code (lines ~1600-1800)
- Purpose: Gets AD object metadata (pwdLastSet, version info, etc.)
- Uses S.DS.P or native .NET calls

**Test-ADReplicationConvergence.ps1**
- Extract from: `checkADReplicationConvergence` function (lines ~2000-2400)
- Purpose: Monitors replication convergence across DCs
- Checks if password change has replicated

**Invoke-ADReplication.ps1**
- Extract from: Replication trigger code (lines ~1800-2000)
- Purpose: Triggers replication for single object
- Uses repadmin or S.DS.P

### Phase 5: Test Object Functions

Create these files in `Private\TestObjects\`:

**New-TemporaryCanaryObject.ps1**
- Extract from: `createTempCanaryObject` function (lines ~2400-2600)
- Purpose: Creates temporary contact object for replication testing
- Used in Mode 2

**Remove-TemporaryCanaryObject.ps1**
- Extract from: Canary deletion code (lines ~2600-2700)
- Purpose: Removes temporary canary object
- Cleanup after Mode 2

**New-InternalTestKrbTgtAccount.ps1**
- Extract from: `createTestKrbTgtADAccount` function (lines ~2700-3100)
- Purpose: Creates TEST/BOGUS KrbTgt accounts
- Used in Mode 8 (internal implementation)

**Remove-InternalTestKrbTgtAccount.ps1**
- Extract from: `deleteTestKrbTgtADAccount` function (lines ~3100-3300)
- Purpose: Removes TEST/BOGUS KrbTgt accounts
- Used in Mode 9 (internal implementation)

### Phase 6: S.DS.P LDAP Module

The S.DS.P module is embedded in the original script (lines 525-5000). Extract all functions to `Private\LDAP\`:

**Key S.DS.P Functions to Extract:**
1. `Find-LdapObject` - LDAP search operations
2. `Get-RootDSE` - Root DSE retrieval
3. `Get-LdapConnection` - LDAP connection management
4. `Add-LdapObject` - Create LDAP objects
5. `Edit-LdapObject` - Modify LDAP objects
6. `Remove-LdapObject` - Delete LDAP objects
7. Helper classes and functions

**Extraction Process:**
```powershell
# The S.DS.P module is between these markers:
# Start: Line 525 - "# S.DS.P PowerShell Module v2.1.5"
# End: Line ~5000 - Before "# DECLARE VARIABLES"

# Create a single file or multiple files:
# Option 1: Single file
Private\LDAP\S.DS.P-Core.ps1

# Option 2: Multiple files (recommended)
Private\LDAP\Find-LdapObject.ps1
Private\LDAP\Get-LdapConnection.ps1
Private\LDAP\Get-RootDSE.ps1
# ... etc
```

### Phase 7: Public Functions

Create these files in `Public\`:

**Reset-KrbTgtPassword.ps1**
This is the main public function. Extract from the main execution flow (lines ~5300-7800):

Structure:
```powershell
function Reset-KrbTgtPassword {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # All parameters from original script
        # Map old parameter names to new ones
    )
    
    begin {
        # Initialize logging
        # Show header (if not skipped)
        # Validate prerequisites
    }
    
    process {
        # Mode selection and validation
        # Target forest/domain selection
        # Execute selected mode (switch statement)
        switch ($Mode) {
            'Info' { # Mode 1 logic }
            'SimulateCanary' { # Mode 2 logic }
            'SimulateTest' { # Mode 3 logic }
            'ResetTest' { # Mode 4 logic }
            'SimulateProd' { # Mode 5 logic }
            'ResetProd' { # Mode 6 logic }
        }
    }
    
    end {
        # Send email if requested
        # Cleanup
    }
}
```

**New-TestKrbTgtAccount.ps1**
Extract Mode 8 logic (~lines 7300-7500):
```powershell
function New-TestKrbTgtAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetDomain,
        
        [Parameter()]
        [PSCredential]$Credential
    )
    
    # Calls New-InternalTestKrbTgtAccount for RWDCs
    # Calls New-InternalTestKrbTgtAccount for each RODC
}
```

**Remove-TestKrbTgtAccount.ps1**
Extract Mode 9 logic (~lines 7500-7700):
```powershell
function Remove-TestKrbTgtAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetDomain,
        
        [Parameter()]
        [PSCredential]$Credential
    )
    
    # Calls Remove-InternalTestKrbTgtAccount for RWDCs
    # Calls Remove-InternalTestKrbTgtAccount for each RODC
}
```

### Phase 8: Configuration and Help

**Config\MailConfig.xml**
Extract from script documentation (lines 500-520):
- Create XML template for email configuration
- Include all required settings (SMTP, credentials, S/MIME, etc.)

**en-US\about_Reset-KrbTgtPassword.help.txt**
Create comprehensive help documentation:
- Module overview
- Function descriptions
- Parameter details
- Examples for each mode
- Best practices
- Troubleshooting guide

## Extraction Best Practices

### 1. Function Extraction Steps
For each function to extract:

1. **Locate** the function in the original script
2. **Copy** the function code
3. **Create** new .ps1 file in appropriate folder
4. **Add** proper comment-based help
5. **Update** function name if needed (e.g., camelCase → Verb-Noun)
6. **Add** parameter validation
7. **Add** error handling (try/catch)
8. **Replace** global variable references with $Script: scope
9. **Test** the function independently

### 2. Variable Scope Conversions

Original script uses various scopes. Convert as follows:

| Original | Module Equivalent | Usage |
|----------|------------------|-------|
| Global vars | `$Script:VarName` | Module-level state |
| Function params | Keep as-is | Function parameters |
| Local vars | Keep as-is | Function-local variables |

### 3. Dependency Management

Track function dependencies:
```powershell
# Example: Set-KrbTgtPassword depends on:
# - New-ComplexPassword (utility)
# - Test-PasswordComplexity (utility)
# - Edit-LdapObject (S.DS.P/LDAP)
# - Write-Log (utility)
```

### 4. Testing Strategy

Test each function as you extract it:
```powershell
# Import module
Import-Module .\Reset-KrbTgtPassword\Reset-KrbTgtPassword.psd1 -Force

# Test individual function
Test-PortConnection -ComputerName "dc01.contoso.com" -Port 389 -Verbose

# Test password generation
$pwd = New-ComplexPassword -Length 32 -Verbose
Test-PasswordComplexity -Password $pwd
```

## Parameter Mapping

Map old script parameters to new module parameters:

| Original Script Parameter | New Module Parameter | Notes |
|---------------------------|----------------------|-------|
| `$modeOfOperation` | `-Mode` | Simplified values |
| `$targetedADforestFQDN` | `-TargetForest` | Clearer name |
| `$targetedADdomainFQDN` | `-TargetDomain` | Clearer name |
| `$targetKrbTgtAccountScope` | `-Scope` | Simplified |
| `$targetRODCFQDNList` | `-TargetRODCs` | Array of strings |
| `$continueOps` | `-ContinueOnWarning` | More descriptive |
| `$sendMailWithLogFile` | `-SendEmailReport` | More descriptive |
| `$noInfo` | `-SkipInfo` | More descriptive |

## Mode Value Mapping

| Original Mode | New Mode Parameter Value |
|---------------|-------------------------|
| `infoMode` | `Info` |
| `simulModeCanaryObject` | `SimulateCanary` |
| `simulModeKrbTgtTestAccountsWhatIf` | `SimulateTest` |
| `resetModeKrbTgtTestAccountsResetOnce` | `ResetTest` |
| `simulModeKrbTgtProdAccountsWhatIf` | `SimulateProd` |
| `resetModeKrbTgtProdAccountsResetOnce` | `ResetProd` |

## Quick Start for Developers

To continue development:

```powershell
# 1. Open the original script
code "c:\Users\user\Documents\Public-AD-Scripts\Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1"

# 2. Open this guide
code "c:\Users\user\Documents\Public-AD-Scripts\Reset-KrbTgtPassword\EXTRACTION_GUIDE.md"

# 3. Start with Phase 2 (Authentication functions)
#    Extract functions one at a time following the steps above

# 4. Test each function as you go
Import-Module .\Reset-KrbTgtPassword\Reset-KrbTgtPassword.psd1 -Force -Verbose

# 5. Use grep to find function definitions in original script
Select-String -Path "Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1" -Pattern "^Function " -CaseSensitive
```

## Estimated Effort

| Phase | Functions | Est. Hours |
|-------|-----------|------------|
| Phase 1 (Utilities) - Remaining | 5 | 3-4 hours |
| Phase 2 (Authentication) | 3 | 2-3 hours |
| Phase 3 (Validation) | 3 | 2-3 hours |
| Phase 4 (AD Operations) | 6 | 6-8 hours |
| Phase 5 (Test Objects) | 4 | 4-5 hours |
| Phase 6 (S.DS.P Module) | 20+ | 8-12 hours |
| Phase 7 (Public Functions) | 3 | 8-12 hours |
| Phase 8 (Config & Help) | 2 | 2-3 hours |
| **Total** | **~50** | **35-50 hours** |

## Next Steps

1. ✅ **COMPLETED**: Module structure and framework
2. ⏭️ **NEXT**: Complete Phase 1 (remaining utility functions)
3. Continue with Phases 2-8 in order
4. Test each phase before moving to the next
5. Create Pester tests for each function (optional but recommended)
6. Update README with any changes
7. Create examples and use cases

## Questions?

Refer to:
- Original script: `Reset-KrbTgt-Password-For-RWDCs-And-RODCs.ps1`
- This guide: `EXTRACTION_GUIDE.md`
- Module README: `README.md`
- Line numbers are approximate - search by function name if needed

Good luck with the extraction! 🚀
