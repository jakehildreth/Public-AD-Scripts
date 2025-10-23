# Reset-KrbtgtPassword Module - Usage Examples

## Table of Contents
- [Module Import](#module-import)
- [Mode 1: Information](#mode-1-information)
- [Mode 2: Canary Simulation](#mode-2-canary-simulation)
- [Mode 3: TEST Simulation](#mode-3-test-simulation)
- [Mode 4: TEST Reset](#mode-4-test-reset)
- [Mode 5: PROD Simulation](#mode-5-prod-simulation)
- [Mode 6: PROD Reset](#mode-6-prod-reset)
- [Create TEST Accounts (New-TestKrbtgtAccount)](#create-test-accounts-new-testkrbtgtaccount)
- [Delete TEST Accounts (Remove-TestKrbtgtAccount)](#delete-test-accounts-remove-testkrbtgtaccount)
- [Advanced Usage](#advanced-usage)

---

## Module Import

```powershell
# Import the module
Import-Module "C:\Path\To\Reset-KrbtgtPassword\Reset-KrbtgtPassword.psd1"

# Verify module loaded
Get-Module Reset-KrbtgtPassword

# Check available commands
Get-Command -Module Reset-KrbtgtPassword
```

**Output:**
```
CommandType     Name                           Version    Source
-----------     ----                           -------    ------
Function        New-TestKrbtgtAccount          4.0.0      Reset-KrbtgtPassword
Function        Remove-TestKrbtgtAccount       4.0.0      Reset-KrbtgtPassword
Function        Reset-KrbtgtPassword           4.0.0      Reset-KrbtgtPassword
```

---

## Mode 1: Information

**Purpose:** Gather information about domain controllers and Krbtgt accounts without making any changes.

### Interactive Mode
```powershell
Reset-KrbtgtPassword
# Select Mode: 1
# Enter domain: contoso.com
```

### Automated Mode
```powershell
Reset-KrbtgtPassword -Mode Info -TargetDomain "contoso.com"
```

### With Remote Domain Credentials
```powershell
$cred = Get-Credential
Reset-KrbtgtPassword -Mode Info -TargetDomain "remote.domain.com" -Credential $cred
```

**Output Example:**
```
INFORMATIONAL MODE - Analyzing environment (no changes)

Domain Controllers in contoso.com:

  - DC01.contoso.com [PDC FSMO]
      Type: RWDC
      Site: Default-First-Site-Name
      IP: 192.168.1.10
      OS: Windows Server 2022 Standard
      Krbtgt Account: krbtgt
      Password Last Set: 01/15/2024 10:30:00

  - DC02.contoso.com
      Type: RWDC
      Site: Default-First-Site-Name
      IP: 192.168.1.11
      OS: Windows Server 2022 Standard
      Krbtgt Account: krbtgt

  - RODC01.contoso.com
      Type: RODC
      Site: Branch-Site
      IP: 192.168.2.10
      OS: Windows Server 2019 Standard
      Krbtgt Account: krbtgt_12345
      Password Last Set: 01/15/2024 10:30:00
```

---

## Mode 2: Canary Simulation

**Purpose:** Test Active Directory replication by creating a temporary canary object.

### Basic Usage
```powershell
Reset-KrbtgtPassword -Mode SimulateCanary -TargetDomain "contoso.com" -Scope AllRWDCs
```

### Interactive Mode
```powershell
Reset-KrbtgtPassword
# Select Mode: 2
# Enter domain: contoso.com
# Select Scope: 1 (All RWDCs)
```

**Output Example:**
```
CANARY SIMULATION MODE - Testing replication with temporary object

Creating temporary canary object...
Canary object created: CN=_adReplTempObject_krbtgt_20240115103000,CN=Users,DC=contoso,DC=com

Monitoring replication convergence...
Replication converged successfully
Time taken: 00:02:15
Replicated to 3 DCs

Removing canary object...
Canary object removed successfully
```

---

## Mode 3: TEST Simulation

**Purpose:** Simulate password reset for TEST Krbtgt accounts without actually changing anything (WhatIf mode).

### All RWDCs
```powershell
Reset-KrbtgtPassword -Mode SimulateTest -TargetDomain "contoso.com" -Scope AllRWDCs
```

### All RODCs
```powershell
Reset-KrbtgtPassword -Mode SimulateTest -TargetDomain "contoso.com" -Scope AllRODCs
```

### Specific RODCs
```powershell
Reset-KrbtgtPassword -Mode SimulateTest -TargetDomain "contoso.com" -Scope SpecificRODCs -TargetRODCs @("RODC01.contoso.com", "RODC02.contoso.com")
```

**Output Example:**
```
TEST SIMULATION MODE - Simulating password reset (WhatIf)

The following accounts would have their passwords reset:
  - krbtgt_TEST [RWDC]
      DC: DC01.contoso.com
  - krbtgt_12345_TEST [RODC]
      DC: RODC01.contoso.com

Simulation complete (no changes made)
```

---

## Mode 4: TEST Reset

**Purpose:** Actually reset passwords for TEST Krbtgt accounts (safe to test replication without affecting production).

### Basic Usage
```powershell
Reset-KrbtgtPassword -Mode ResetTest -TargetDomain "contoso.com" -Scope AllRWDCs
```

### With Confirmation Bypass (for automation)
```powershell
Reset-KrbtgtPassword -Mode ResetTest -TargetDomain "contoso.com" -Scope AllRWDCs -ContinueOnWarning -Confirm:$false
```

### All RODCs
```powershell
Reset-KrbtgtPassword -Mode ResetTest -TargetDomain "contoso.com" -Scope AllRODCs
```

**Output Example:**
```
TEST RESET MODE - Resetting TEST account passwords

Are you sure you want to reset TEST account passwords? [YES/NO]: YES

Resetting krbtgt_TEST password...
Password reset successful
Previous password set: 01/15/2024 10:30:00
New password set: 01/15/2024 14:45:00
Forcing replication...
Replication initiated to DC02.contoso.com
Replication initiated to DC03.contoso.com

TEST account password reset complete
```

---

## Mode 5: PROD Simulation

**Purpose:** Simulate password reset for PRODUCTION Krbtgt accounts without actually changing anything (WhatIf mode).

### All RWDCs
```powershell
Reset-KrbtgtPassword -Mode SimulateProd -TargetDomain "contoso.com" -Scope AllRWDCs
```

### All RODCs
```powershell
Reset-KrbtgtPassword -Mode SimulateProd -TargetDomain "contoso.com" -Scope AllRODCs
```

**Output Example:**
```
PRODUCTION SIMULATION MODE - Simulating password reset (WhatIf)
WARNING: This shows what would happen in PRODUCTION!

The following PRODUCTION accounts would have their passwords reset:
  - krbtgt [RWDC]
      DC: DC01.contoso.com
  - krbtgt_12345 [RODC]
      DC: RODC01.contoso.com

Simulation complete (no changes made)
```

---

## Mode 6: PROD Reset

**Purpose:** Reset PRODUCTION Krbtgt account passwords (⚠️ **LIVE DOMAIN IMPACT** ⚠️).

### ⚠️ WARNING
This operation will:
- Invalidate ALL Kerberos tickets in the domain
- Force users and services to re-authenticate
- Potentially cause service disruptions
- Should only be performed during maintenance windows

### Basic Usage
```powershell
Reset-KrbtgtPassword -Mode ResetProd -TargetDomain "contoso.com" -Scope AllRWDCs
```

### With Confirmation Bypass (for automation - USE WITH EXTREME CAUTION)
```powershell
Reset-KrbtgtPassword -Mode ResetProd -TargetDomain "contoso.com" -Scope AllRWDCs -ContinueOnWarning -Confirm:$false
```

**Output Example:**
```
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! PRODUCTION RESET MODE - LIVE DOMAIN IMPACT !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

This will reset PRODUCTION Krbtgt account passwords!
This will cause ALL Kerberos tickets to be invalidated!
Users and services will need to re-authenticate!

Type 'I UNDERSTAND THE IMPACT' to continue: I UNDERSTAND THE IMPACT

Final confirmation - Type 'PROCEED' to reset production passwords: PROCEED

Beginning PRODUCTION password reset...

Resetting krbtgt password...
PRODUCTION password reset successful
Previous password set: 01/15/2024 10:30:00
New password set: 01/15/2024 14:45:00
Forcing replication to all RWDCs...
Monitoring replication convergence...
Replication converged successfully

PRODUCTION password reset complete
Monitor domain for authentication issues
```

---

## Create TEST Accounts (New-TestKrbtgtAccount)

**Purpose:** Create TEST Krbtgt accounts (krbtgt_TEST and krbtgt_<Number>_TEST) for safe testing.

**Note:** This is a separate function, not a mode of Reset-KrbtgtPassword.

### Basic Usage
```powershell
New-TestKrbtgtAccount -TargetDomain "contoso.com"
```

### With Remote Domain Credentials
```powershell
$cred = Get-Credential
New-TestKrbtgtAccount -TargetDomain "remote.domain.com" -Credential $cred
```

### With WhatIf (preview only)
```powershell
New-TestKrbtgtAccount -TargetDomain "contoso.com" -WhatIf
```

**Output Example:**
```
------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TEST KRBTGT ACCOUNTS...

Do you really want to continue and create TEST Krbtgt accounts? [CONTINUE | STOP]: CONTINUE

  --> Chosen: CONTINUE

+++++
+++ Create Test Krbtgt Account...: 'krbtgt_TEST' +++
+++ Used By RWDC.................: 'All RWDCs' +++
+++++

Creating test Krbtgt account: krbtgt_TEST
Account created successfully
Set password for: CN=krbtgt_TEST,CN=Users,DC=contoso,DC=com
Added to group: CN=Denied RODC Password Replication Group,CN=Users,DC=contoso,DC=com

+++++
+++ Create Test Krbtgt Account...: 'krbtgt_12345_TEST' +++
+++ Used By RODC.................: 'RODC01.contoso.com' (Site: Branch-Site) +++
+++++

Creating test Krbtgt account: krbtgt_12345_TEST
Account created successfully
Set password for: CN=krbtgt_12345_TEST,CN=Users,DC=contoso,DC=com
Added to group: CN=Allowed RODC Password Replication Group,CN=Users,DC=contoso,DC=com

All TEST Krbtgt accounts have been processed.
------------------------------------------------------------------------------------------------------------------------------------------------------
```

---

## Delete TEST Accounts (Remove-TestKrbtgtAccount)

**Purpose:** Remove all TEST Krbtgt accounts created by New-TestKrbtgtAccount.

**Note:** This is a separate function, not a mode of Reset-KrbtgtPassword.

### Basic Usage
```powershell
Remove-TestKrbtgtAccount -TargetDomain "contoso.com"
```

### With Remote Domain Credentials
```powershell
$cred = Get-Credential
Remove-TestKrbtgtAccount -TargetDomain "remote.domain.com" -Credential $cred
```

### With WhatIf (preview only)
```powershell
Remove-TestKrbtgtAccount -TargetDomain "contoso.com" -WhatIf
```

**Output Example:**
```
------------------------------------------------------------------------------------------------------------------------------------------------------
CLEANUP TEST KRBTGT ACCOUNTS...

Do you really want to continue and delete TEST Krbtgt accounts? [CONTINUE | STOP]: CONTINUE

  --> Chosen: CONTINUE

+++++
+++ Delete Test Krbtgt Account...: 'krbtgt_TEST' +++
+++ Used By RWDC.................: 'All RWDCs' +++
+++++

Removing test Krbtgt account: krbtgt_TEST
Account removed successfully

+++++
+++ Delete Test Krbtgt Account...: 'krbtgt_12345_TEST' +++
+++ Used By RODC.................: 'RODC01.contoso.com' (Site: Branch-Site) +++
+++++

Removing test Krbtgt account: krbtgt_12345_TEST
Account removed successfully

All TEST Krbtgt accounts have been processed.
------------------------------------------------------------------------------------------------------------------------------------------------------
```

---

## Advanced Usage

### Scripted Workflow: Full Test Cycle

```powershell
# 1. Import module
Import-Module "C:\Path\To\Reset-KrbtgtPassword\Reset-KrbtgtPassword.psd1"

# 2. Gather information
Reset-KrbtgtPassword -Mode Info -TargetDomain "contoso.com"

# 3. Test replication with canary
Reset-KrbtgtPassword -Mode SimulateCanary -TargetDomain "contoso.com" -Scope AllRWDCs

# 4. Create TEST accounts
New-TestKrbtgtAccount -TargetDomain "contoso.com" -Confirm:$false

# 5. Simulate TEST reset
Reset-KrbtgtPassword -Mode SimulateTest -TargetDomain "contoso.com" -Scope AllRWDCs

# 6. Perform TEST reset
Reset-KrbtgtPassword -Mode ResetTest -TargetDomain "contoso.com" -Scope AllRWDCs -ContinueOnWarning -Confirm:$false

# 7. Simulate PROD reset
Reset-KrbtgtPassword -Mode SimulateProd -TargetDomain "contoso.com" -Scope AllRWDCs

# 8. Clean up TEST accounts
Remove-TestKrbtgtAccount -TargetDomain "contoso.com" -Confirm:$false
```

### Production Workflow (with proper testing)

```powershell
# Week 1: Create and test with TEST accounts
New-TestKrbtgtAccount -TargetDomain "prod.contoso.com"
Reset-KrbtgtPassword -Mode ResetTest -TargetDomain "prod.contoso.com" -Scope AllRWDCs
# Monitor for 24-48 hours

# Week 2: Simulate production reset
Reset-KrbtgtPassword -Mode SimulateProd -TargetDomain "prod.contoso.com" -Scope AllRWDCs
# Review simulation results

# Week 3: During maintenance window, perform production reset
Reset-KrbtgtPassword -Mode ResetProd -TargetDomain "prod.contoso.com" -Scope AllRWDCs
# Monitor closely for authentication issues

# Week 4: Verify and perform second reset (Microsoft recommendation)
Reset-KrbtgtPassword -Mode ResetProd -TargetDomain "prod.contoso.com" -Scope AllRWDCs

# Clean up TEST accounts
Remove-TestKrbtgtAccount -TargetDomain "prod.contoso.com"
```

### Multi-Forest Environment

```powershell
# Local forest
Reset-KrbtgtPassword -Mode Info -TargetDomain "local.contoso.com"

# Remote forest (requires credentials)
$remoteCred = Get-Credential "REMOTE\Administrator"
Reset-KrbtgtPassword -Mode Info -TargetDomain "remote.fabrikam.com" -Credential $remoteCred
```

### RODC-Specific Operations

```powershell
# Target only RODCs
Reset-KrbtgtPassword -Mode ResetTest -TargetDomain "contoso.com" -Scope AllRODCs

# Target specific RODCs
$targetRODCs = @(
    "RODC-Branch1.contoso.com",
    "RODC-Branch2.contoso.com"
)
Reset-KrbtgtPassword -Mode ResetTest -TargetDomain "contoso.com" -Scope SpecificRODCs -TargetRODCs $targetRODCs
```

---

## Logging

All operations are automatically logged to:
```
<ModulePublicFolder>\<YYYY-MM-DD_HH.mm.ss>_<COMPUTERNAME>_Reset-KrbtgtPassword.log
```

Example:
```
C:\...\Reset-KrbtgtPassword\Public\2025-10-22_10.25.59_ADCSGOAT-PAW_Reset-KrbtgtPassword.log
```

The log file path is displayed at the end of each operation. To view it:
```powershell
# The log path is shown in the final output
# Look for: "Log file: C:\path\to\logfile.log"
```

---

## Best Practices

1. **Always test first:**
   - Use Mode 1 (Info) to understand the environment
   - Use Mode 2 (SimulateCanary) to test replication
   - Create TEST accounts with New-TestKrbtgtAccount
   - Test with Mode 3/4 before production

2. **Production resets:**
   - Schedule during maintenance windows
   - Reset twice (10 hours apart minimum) per Microsoft guidance
   - Monitor authentication closely
   - Have rollback plan ready

3. **RODCs:**
   - Reset RODC Krbtgt accounts independently
   - Monitor branch connectivity
   - Consider impact on cached credentials

4. **Automation:**
   - Use `-ContinueOnWarning` and `-Confirm:$false` only in tested scripts
   - Always review simulation output first
   - Implement proper error handling

5. **Security:**
   - Run with elevated privileges
   - Use secure credential handling
   - Review logs for anomalies
   - Document all production changes

---

## Troubleshooting

### Module Not Found
```powershell
# Verify path
Test-Path "C:\Path\To\Reset-KrbtgtPassword\Reset-KrbtgtPassword.psd1"

# Import with full path
Import-Module "C:\Path\To\Reset-KrbtgtPassword\Reset-KrbtgtPassword.psd1" -Force
```

### Permission Errors
```powershell
# Verify elevation
Test-LocalElevation

# Verify domain admin rights
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
```

### Replication Issues
```powershell
# Check DC connectivity
Get-ADDomainControllers -DomainFQDN "contoso.com"

# Test replication with canary first
Reset-KrbtgtPassword -Mode SimulateCanary -TargetDomain "contoso.com" -Scope AllRWDCs
```

### LDAP Connection Errors
```powershell
# Test connectivity to specific DC
Test-PortConnection -Server "DC01.contoso.com" -Port 389 -Protocol TCP
Test-PortConnection -Server "DC01.contoso.com" -Port 636 -Protocol TCP
```

---

## Support

For issues, questions, or contributions:
- GitHub: https://github.com/zjorz/Public-AD-Scripts
- Original Script: Reset-Krbtgt-Password-For-RWDCs-And-RODCs.ps1 v3.4
- Module Version: Reset-KrbtgtPassword v4.0.0
