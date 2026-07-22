# Runbook: Mass AD User Provisioning with JSON Schema

**ID:** runbook-2026-05-26-003-mass-ad-user-provisioning-with-json-schema

**Owner:** @tobondev

**Severity class:** Medium

**Last tested:** 2026-05-26

**Estimated execution time:** ~10 minutes (script runtime scales O(n) with user count)

**Automation hooks:** Manual execution via PowerShell Remoting or scheduled task

**Prerequisites:**
- Domain Controller running Windows Server with AD DS installed
- PowerShell 5.1+
- Internet access from the DC (required to download scripts from GitHub in Step 1)
- Administrative credentials for `tobon.dev`
- Optional: a test OU structure already present

**Trigger:** Need to populate or refresh the lab Active Directory with a large number of test users (e.g., 1,000) for load testing, security scenario exercises (Stage 5), or to re-establish a known identity baseline after a domain restore.

> **Note on automation:** `Delete-All-FakeAccounts.ps1` and `Verify-ProvisioningState.ps1` were created during the runbook drafting and testing process. Manual teardown and verification were too complex to express reliably as inline commands. For this reason, the runbook now starts with the step of downloading a helper script, which then populates and organizing the working environment.

---

## 1. Execution Steps

**1. Stage the working environment.**

Download and execute the helper script. It is location-agnostic: it creates the required directory structure, moves itself into place, sets the working directory to `C:\Scripts\Admin\UserProvisioning`, and downloads all provisioning scripts from the repository via the GitHub API.

```powershell
# Download the helper script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/tobondev/homelab/main/scripts/admin/windows/utils/Download-ProvisioningScripts.ps1" `
                  -OutFile ".\Download-ProvisioningScripts.ps1"
# Execute the helper script
.\Download-ProvisioningScripts.ps1
```

Upon completion, the directory structure will be:

| Working Scripts | Helper Script |
| --- | --- |
| `C:\Scripts\Admin\UserProvisioning` | `C:\Scripts\Admin\HelperScripts` |

*(Expected output: a directory listing of `Generate-TestCSV.ps1`, `CSV-To-JSON-user-provisioning.ps1`, `Provision-From-JSON.ps1`, `Delete-All-FakeAccounts.ps1`, and `Verify-ProvisioningState.ps1`)*

**2. Confirm working directory context.**

The helper script automatically sets the working directory to `C:\Scripts\Admin\UserProvisioning` via `Set-Location`. All subsequent relative paths in this runbook are anchored to that directory. Verify the context before proceeding:

```powershell
Get-Location
# Expected: C:\Scripts\Admin\UserProvisioning

Get-ChildItem | Select-Object Name
# Expected: all five .ps1 scripts listed above
```

**3. [OPTIONAL] Clean existing synthetic users.**

If re-provisioning over a previous run, use the teardown script to remove all synthetic users and destroy all lab OUs before proceeding. Skip this step if provisioning for the first time or deliberately adding to an existing set.

```powershell
.\Delete-All-FakeAccounts.ps1
```

*(Expected output: a list of purged users and destroyed OUs, ending with `"Teardown complete. Lab environment is clean."`)*

**4. Generate test CSV with 1,000+ users.**

```powershell
.\Generate-TestCSV.ps1
```

*(Expected output: `"Success! Created .\users.csv with X rows"` where X = 1000)*

The script creates:
- 997 standard users distributed across departments (IT Operations, Finance, Sales, etc.)
- 3 Kerberoastable service accounts (`smssql`, `shttp`, `sbackup`) assigned to the `_SERVICE` department
- ~100 users flagged with the `InvalidPassword` group, triggering weak password generation
- All users added to the `FakeAccounts` group to enable bulk deletion

**5. Convert CSV to JSON schema.**

```powershell
.\CSV-To-JSON-user-provisioning.ps1
```

*(Expected output: `"Success: Identity state locked and saved to .\users.json"`)*

This step:
- Resolves username collisions using letter expansion and numeric fallbacks
- Assigns password complexity per group membership (LOW / MEDIUM / HIGH / INVALID / ROAST)
- Generates random passwords per tier rules (length 4–16, character pools 2–4)
- Writes a single `users.json` containing all users, groups, and SPNs

**6. Provision users from JSON.**

```powershell
.\Provision-From-JSON.ps1
```

*(Expected output: a scrolling list of `"Provisioned: username -> OU=Department,DC=tobon,DC=dev"` entries, followed by `"Password Policy restored. Lab environment staging complete."`)*

> **Important:** This script wraps execution in a `try/finally` block. It temporarily disables domain password complexity to allow deliberately weak accounts, and unconditionally restores the policy on exit — including on error or manual interruption. If any user fails to provision (duplicate, invalid OU, etc.), a warning is printed to the console and the error is appended to `.\provisioning_errors.log`. Provisioning continues for all remaining users.

**7. Run the automated verification suite.**

```powershell
.\Verify-ProvisioningState.ps1
```

*(Expected output: a full checklist of `[PASS]` results across OU population, FakeAccounts group membership, Kerberoastable SPN attributes, password policy restoration, and error log status, culminating in `"ALL TESTS PASSED. Provisioning is ready for next stage."`)*

A timestamped transcript is automatically saved to:
`C:\Scripts\Admin\UserProvisioning\Artifacts\2026_AD_Provisioning_Verification_YYYYMMDD_HHmm.log`

---

## 2. Verification

Verification is handled entirely by `Verify-ProvisioningState.ps1`. Review the generated transcript at the path above to confirm:

- Total user counts match expectations (1,000)
- The `FakeAccounts` group is fully populated (1,000 members)
- Kerberoastable accounts (`smssql`, `shttp`, `sbackup`) carry the correct `ServicePrincipalName` attributes
- Default Domain Password Policy complexity and minimum length are restored
- `.\provisioning_errors.log` is absent or empty

---

## 3. Rollback Plan

If provisioning introduces errors or you need to revert to a clean state before the next stage:

**1. Run the teardown script:**

```powershell
.\Delete-All-FakeAccounts.ps1
```

*(Expected output: purge and OU destruction log ending with `"Teardown complete. Lab environment is clean."`)*

The script targets the `FakeAccounts` group membership for user deletion, then destroys all lab OUs by name (including `_GROUPS`, which contains the `FakeAccounts` group itself). No manual filtering is required.

**2. Verify the teardown:**

```powershell
# Confirm the FakeAccounts group is gone (expect: no output)
Get-ADGroup -Filter "Name -eq 'FakeAccounts'" -ErrorAction SilentlyContinue

# Spot-check OU destruction (expect: no output)
Get-ADOrganizationalUnit -Filter "Name -eq '_SERVICE'" -ErrorAction SilentlyContinue
```

Both commands should return nothing. Any output indicates a partial teardown; re-run the teardown script.

**Estimated RTO:** 5 minutes.

---

## 4. Post-Ops

- [ ] If `provisioning_errors.log` contains entries, review and manually remediate failed users.
- [ ] Commit `users.json` and the generated verification transcript to the repository as artifacts for reproducibility and documentation.
- [ ] **Before Stage 3 (Entra ID Connect):** Delete all insecure accounts. Re-run `Delete-All-FakeAccounts.ps1`, then re-provision with a clean, complexity-compliant user set before initiating cloud sync.

---

## 5. Lifecycle / Normalization

When moving from Stage 2 to Stage 3 (cloud sync), deliberately weak and Kerberoastable accounts must be removed. Run the teardown script, take a clean snapshot, then re-provision without the insecure tiers.

To regenerate the user set with different parameters, edit the following variables in `Generate-TestCSV.ps1` before repeating Steps 3–6:

- `$firstNames`, `$lastNames` arrays
- `$departments` hashtable (to add or remove OUs)
- The `InvalidPassword` injection percentage (line ~70)
- `$serviceAccounts` array for Kerberoastable SPNs (maintaining the `s` + `lastname` naming convention)

---

## 6. Change Log

| Date | Author | Note |
| --- | --- | --- |
| 2026-05-26 | @tobondev | Initial draft based on Stage 2 implementation. Integrated automated verification suite and transcript generation. `Delete-All-FakeAccounts.ps1` and `Verify-ProvisioningState.ps1` created during drafting to address teardown and verification complexity. |
| 2026-07-24 | @tobondev | Full Validation of Script Download and Runbook Execution. |
