# ADR 004: Implementing SOPS as the Production Secrets Management

File: adr-2026-04-10-004-implementing-sops-as-the-production-secrets-management.md
Title: Implementing SOPS as the Production Secrets Management
Date: 2026-04-10
Status: Implemented
Decider(s): Marcos Tobon
Owner: @tobondev
Confidence: High
Review-by: 2026-06-10

---

## 1. Context and Problem Statement

**One-line summary:** Adopt Mozilla SOPS with AGE encryption to manage and version infrastructure secrets within the public Git repository.

**Background:**

The current workflow maintains two parallel files for each secrets-containing configuration: a live `.env` file with real credentials, excluded from version control via `.gitignore`, and a manually maintained sanitized counterpart containing dummy values that is safe to commit publicly. As configurations evolve, both files must be kept in sync manually — a burden that has already deferred publication of the Docker infrastructure configurations entirely, and will only compound as the Ansible provisioning project (ADR-003) grows. Automated pipelines cannot safely reference the sanitized files without substitution logic, undermining the GitOps model the repository is built around.

This decision was also triggered directly by ADR-003: Section 7 of that document identifies a residual risk — the shared Ansible management key — whose resolution path explicitly depends on a secrets management architecture being in place.

---

## 2. Considered Options

| Option ID | Short name | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|
| A | `.gitignore` / `.env` exclusion | Low | None | Low | Immediate |
| B | HashiCorp Vault | High | Low | High | 2-4 weeks |
| C | `git-crypt` | Medium | None | Low | 1 week |
| D | SOPS + AGE | High | None | Low | < 2 days |

#### Option A: `.gitignore` / `.env` exclusion

**Description:** The traditional method of keeping secrets out of version control by completely ignoring the files that contain them. This is the current solution in production.

- **Pros:**
  - Zero friction, immediate implementation, requires no additional tooling or key management.
- **Cons:**
  - Completely decouples secret management from the configuration state. Automated pipelines lose their source of truth, and a public repository viewer cannot see the structural logic of the deployment.
  - Requires manual maintenance of parallel sanitized counterparts, which drift from the live configuration over time.

#### Option B: HashiCorp Vault

**Description:** Deploying an enterprise-grade, stateful secrets management server to handle dynamic secrets, encryption as a service, and strict access controls.

- **Pros:**
  - The industry standard for enterprise security. Offers unmatched auditing, dynamic secret generation, and granular Role-Based Access Control (RBAC).
- **Cons:**
  - Introduces massive architectural overhead, requiring the provisioning and maintenance of a highly available central server.
  - Introduces a single point of failure that can result in complete loss of secrets access.
  - Violates KISS principles for a homelab environment.

#### Option C: `git-crypt`

**Description:** A tool that enables transparent encryption and decryption of files in a Git repository using `.gitattributes`.

- **Pros:**
  - Low operational friction once configured; files automatically decrypt on checkout and encrypt on commit, making it transparent to the user.
- **Cons:**
  - A misconfigured `.gitattributes` glob pattern will cause Git to commit a file in plaintext without any warning or error. Unlike a failed `sops -e` invocation — which produces a visible error and leaves the file unmodified — `git-crypt`'s transparent model provides no signal that encryption did not occur. This makes the failure mode invisible during normal `git add` / `git diff` review.

#### Option D: SOPS + AGE

**Description:** Using Mozilla SOPS to explicitly encrypt file values (while preserving keys) combined with AGE, a modern, lightweight cryptographic tool.

- **Pros:**
  - Explicit encryption means the file structure visibly changes to ciphertext and includes Message Authentication Codes (MACs); encryption state can be verified before staging.
  - AGE provides strong cryptography without the complex web-of-trust overhead of PGP.
  - Native integration with Ansible via `community.sops` and zero cloud dependencies.
- **Cons:**
  - Requires strict local key management and discipline.
  - Secrets must be edited through the SOPS CLI wrapper rather than standard text editors to maintain MAC integrity.

---

## 3. Decision Outcome

**Chosen option:** Option D — SOPS + AGE.

**Decision statement:** Implement Mozilla SOPS with AGE encryption to manage repository secrets, utilizing local key storage protected by host-level Full Disk Encryption (FDE) and backed up securely via Bitwarden and encrypted AWS pipelines.

**Rationale:**

The primary objective is to maintain a public-facing GitOps repository that proves infrastructure logic without leaking sensitive credentials. Option A is the easiest but strips valuable context and breaks automated provisioning. Option B is enterprise-grade but introduces unacceptable stateful overhead for a homelab environment.

The decision ultimately comes down to Option C vs. Option D. SOPS is selected because its encryption is explicit rather than transparent. When SOPS encrypts a YAML or JSON file, it encrypts only the values, leaving the keys readable in plaintext. This allows public viewers to understand the configuration structure — network interface names, VLAN assignments, playbook parameters — without seeing the sensitive payloads. Option C carries the critical flaw of failing silently on misconfiguration; SOPS guarantees that unencrypted data will not be accidentally staged, as the file itself is visibly transformed.

Finally, pairing SOPS with AGE rather than PGP (deprecated) or Cloud KMS eliminates reliance on an external cloud provider's API. AGE is a simple, modern, and stateless cryptographic tool that keeps the security boundary entirely local.

---

## 4. Acceptance Criteria (measurable)

- **AC-1:** A production secrets file (`openwrt-secrets.yml`) and inventory file (`hosts.yml`) are committed to the `sops-deployment` branch with all sensitive values cryptographically masked and structural keys preserved in plaintext, verified by `cat` output.
- **AC-2:** Ansible playbooks consume SOPS-encrypted files dynamically during execution against a live node using the `community.sops` collection, verified by a successful provisioning run with no plaintext secrets present in the playbook directory.
- **AC-3:** A `git diff` against `main` confirms zero plaintext leakage — only ciphertext, SOPS metadata, and structural keys are present in the diff output, logged as an artifact prior to merge.
- **AC-4:** The AGE private key is verified as securely vaulted in Bitwarden and recoverable: the key is retrieved from the vault, its `sha256sum` is compared against the working key on disk, and a decryption test against a live SOPS file succeeds.

---

## 5. Test Plan & Artifacts

**Test plan (high level):**

1. Branch from `main` to the untracked local branch `sops-deployment`.
2. Generate an AGE key pair; back up the private key to Bitwarden as a secure note attachment.
3. Encrypt target secrets and inventory files using `sops -e -i` and the generated public key.
4. Verify encryption visually: `cat` output shows ciphertext values with plaintext structural keys; SOPS MAC block is present.
5. Perform a soft reset (`git reset --soft <first-clean-commit>`) to collapse any intermediate commits that may have captured plaintext state prior to encryption. Because `sops-deployment` is an untracked local branch, no force-push is required. The amended commit will contain only ciphertext and SOPS metadata.
6. Execute `git diff main` and log output to confirm zero plaintext leakage prior to merge.
7. Install `community.sops` via Ansible Galaxy; execute a provisioning playbook against a test node to satisfy AC-2.

> **Note on AC-2:** Integration was completed on 2026-04-14. `community.sops.load_vars`> is active in all four production playbooks. See Section 9 and Section 10 for full details.


| Artifact | Path/Link | Short description |
|---------|------|---------|
| Encrypted Secrets File | `host-configs/ansible/playbooks/openwrt/openwrt-secrets.yml` | Production SOPS-encrypted secrets file demonstrating key preservation and value encryption |
| Encrypted Inventory File | `host-configs/ansible/playbooks/openwrt/hosts.yml` | SOPS-encrypted Ansible inventory including host IPs, ports, key paths, and gateway mode flags |
| Git Diff Output | `docs/artifacts/SOPS/git-diff-sops-deployment.md` | Log confirming zero plaintext leakage against main, verified via `git diff-index` prior to merge |
| AGE Key Backup Verification | `docs/artifacts/SOPS/age-key-backup-verification.md` | SHA-256 checksum comparison between working key and Bitwarden-restored copy, plus decryption test result |
| MVP Secrets Test | `docs/artifacts/SOPS/mvp-secret.yml` | Encrypted dummy YAML demonstrating SOPS value encryption and key preservation for portfolio visibility |

---

## 6. Rollback Plan

### Pre-Merge

Due to the isolated local-branch strategy, rollback is immediate and non-destructive to the upstream repository.

1. Abort the deployment and delete the local branch: `git branch -D sops-deployment`.
2. Revert any state changes on test nodes using saved LuCi backups.
3. Delete the test AGE key if there is any reason to suspect compromise.

**Estimated RTO:** < 5 minutes.

### Post-Merge

If SOPS is later replaced entirely:

1. Create a new branch with no upstream tracking.
2. Decrypt all SOPS-managed files: `sops -d <file> > <plaintext-output>` for each file, staged outside the repository.
3. Remove `.sops.yaml` and the `community.sops` Ansible Galaxy dependency.
4. Restore `.gitignore` exclusion for plaintext secrets files.
5. Commit sanitized dummy-value variants for public portfolio visibility.

**Estimated effort:** 1–2 hours. No data loss risk — the AGE key and all plaintext values remain locally accessible throughout.

---

## 7. Trade-offs, Risks and Mitigations

- **Trade-off:** Managing the AGE key locally requires strict personal discipline compared to a managed cloud IAM service. Mitigated by Bitwarden vaulting and 3-2-1 backup coverage.

- **Risk:** Catastrophic local drive failure leading to loss of the decryption key.
  → **Mitigation:** The `key.txt` file is vaulted in Bitwarden and backed up via standard `btrbk` / encrypted AWS pipelines. Recovery verified by checksum comparison (AC-4).

- **Risk:** Accidental commit of unencrypted plaintext secrets to the public repository.
  → **Mitigation:** Strict adherence to the untracked local branch workflow, combined with mandatory `git diff` review and commit history soft-reset prior to merging upstream (AC-3).

---

## 8. Security Impact (CIA)

- **Confidentiality:** High. Sensitive values are encrypted at rest in the public repository using AES-256-GCM. The local decryption key is secured by host-level Full Disk Encryption and backed up in Bitwarden. Delta from current state: eliminates the parallel dummy-file workflow and the risk of accidental `.env` staging.

- **Integrity:** High. SOPS computes and stores a Message Authentication Code (MAC) covering all encrypted values in each file. Any tampering with the ciphertext is detected immediately on decryption attempt. Delta from current state: configuration files in the repository are now tamper-evident; the previous `.gitignore` model provided no integrity guarantee for the committed sanitized files.

- **Availability:** High. Decryption relies entirely on local tools and local keys — deployment pipelines will not fail due to external API outages or network disconnects. Delta from current state: no change to availability posture; secrets were previously available locally and remain so.

---

## 9. Implementation Notes

- The `.sops.yaml` creation rule uses a global `\.ya?ml$` path regex intentionally. The operator selects which files to encrypt by running `sops -e -i`; the pattern enables the tooling to operate on any YAML file in the repository without per-directory configuration overhead. Extend to `.env` files when Docker configurations are published.
- The AGE private key is stored at `~/.sops/key.txt`. The path is exported via `SOPS_AGE_KEY_FILE` in the shell profile. The key is protected at rest by host-level Full Disk Encryption.
- The `sops-deployment` branch was soft-reset to a single clean commit prior to merge. `git diff-index` was executed and the output logged as `docs/artifacts/SOPS/git-diff-sops-deployment.md`. The branch was subsequently merged to `main`. The gitleaks scan output is included as the commit message for the merge commit.

- **Note on AC-2:** `community.sops.load_vars` is integrated into all four production playbooks: `openwrt-provision-nodes.yml`, `ansible-security-hardening.yml`, `port-rotation.yml`, and `openwrt-luci-lockdown.yml`. Integration was verified by successful execution of all four playbooks against live nodes on 2026-04-14. AC-2 is satisfied.

---
## 10. Post-Implementation Review

**Date implemented:** 2026-04-10 (MVP) / 2026-04-14 (Full integration)
**Status:** Implemented

- **AC-1:** Satisfied — `openwrt-secrets.yml` and `hosts.yml` committed to `sops-deployment`
  with all sensitive values encrypted; structural keys preserved and readable. Verified by `cat`
  output in operations log. _(2026-04-10)_

- **AC-2:** Satisfied — `community.sops.load_vars` integrated into all four production playbooks.
  Verified by successful execution against all five active nodes on 2026-04-14. No plaintext
  secrets present in the playbook directory during execution. _(2026-04-14)_
  Additionally, git-leaks was run and its clean output is the commit message for the project merge.

- **AC-3:** Satisfied — `git diff-index` executed against `main` prior to merge. Zero plaintext
  leakage confirmed. All modified files verified as either SOPS-encrypted or structurally safe.
  See `docs/artifacts/SOPS/git-diff-sops-deployment.md`. _(2026-04-10)_

- **AC-4:** Satisfied — AGE private key vaulted in Bitwarden. Recovery verified by `sha256sum`
  comparison and decryption test. See `docs/artifacts/SOPS/age-key-backup-verification.md`.
  _(2026-04-10)_

**Follow-ups:**

- **Note on Fallback_AP secrets:**
  The `Fallback_AP.sops.yml` file has been manually encrypted to satisfy the "Zero Plaintext Leakage" requirement for the public repository. While the Ansible hardening playbook (`ansible-security-hardening.yml`) includes a bootstrap path to automate initial encryption, manual encryption was chosen for this node because it remained "cold" during the mass deployment. The existing Ansible workflow is natively compatible with pre-encrypted host variables.

- ~~Complete Ansible `community.sops` integration and close AC-2~~ ✓ Completed 2026-04-14
- ~~Execute `git diff main` pre-merge gate and log output as artifact~~ ✓ Completed 2026-04-10
- [ ] **Pending:** Implement Jinja2 template for LuCI lockdown artifact to replace manual IP  redaction. Low priority — manual redaction is functional.


---

## Minimal ADR checklist

- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [x] Rolled out and tested recovery plan (AGE key recovery verified 2026-04-10; full integration verified 2026-04-14)

---

## Index Registration

> **Index Entry:** | 004 | 2026-04-10 | [Implementing SOPS as the Production Secrets Management](adrs/adr-2026-04-10-004-implementing-sops-as-the-production-secrets-management.md) | Implemented |
