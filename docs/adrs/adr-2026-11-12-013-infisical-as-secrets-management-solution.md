# ADR 013: Infisical As Secrets Management Solution

**File:** adr-2026-11-12-013-infisical-as-secrets-management-solution.md

**Title:** Infisical As Secrets Management Solution

**Date:** 2026-11-12

**Status:** REJECTED

**Decider(s):** Marcos Tobon

**Owner:** @tobondev

**Confidence:** High

**Review-by:** 2026-12-12

> [Superseded by ADR-004]
---

## 1. Context and Problem Statement

### One-line summary

Replace the file-backed SOPS encryption model with Infisical, a centralized, API-driven secrets manager, to securely inject credentials into the Gitea CI/CD pipeline without committing encrypted secrets to the Git repository.

### Background

The infrastructure currently relies on a localized stop-gap (`sops-update.py`) that encrypts `.env` files into `.sops.env` files committed directly to the repository. While functional for manual deployments, this Tier-1 file-backed model breaks down in an automated GitOps workflow. To deploy autonomously, the Gitea Actions runner (`act_runner`) must be given the master private decryption key (AGE/PGP), turning the runner into a massive single point of compromise. Furthermore, file-backed encryption lacks audit logging (who/what accessed the secret) and makes credential rotation cumbersome. The infrastructure requires a centralized vault that issues short-lived, scoped machine identity tokens to the pipeline at runtime.

## 2. Considered Options

### Summary Table

| Option ID | Short Name | Description | Security Impact | Cost | Complexity | Time to Implement |
| --- | --- | --- | --- | --- | --- | --- |
| A | SOPS | Status Quo: Pre-commit hook with file-backed repository encryption. | Medium | Zero | Low | 0 weeks |
| B | HashiCorp Vault | Deploy the enterprise-standard centralized secrets engine. | High | Zero | *Very High* | 3–4 weeks |
| C | Bitwarden SM | Utilize Bitwarden Secrets Manager (ecosystem extension). | High | Low (Sub) | Low | 1 week |
| D | Infisical | Deploy self-hosted Infisical for developer-centric CI/CD injection. | High | Zero | Medium | 1–2 weeks |

### Option A: SOPS (Status Quo)

* **Pros:** Native GitOps workflow (secrets live alongside code); completely stateless.
* **Cons:** Requires shipping the master decryption key to the CI/CD runner; zero access audit logs; rotating a compromised secret requires re-encrypting and committing files.

### Option B: HashiCorp Vault

* **Pros:** The undisputed industry standard; dynamic secret generation; highly secure transit encryption.
* **Cons:** Extremely high operational overhead. Managing unseal keys (if the server reboots, the vault locks until manually unsealed) and writing complex HCL policies is vastly over-engineered for a single-admin homelab.

### Option C: Bitwarden Secrets Manager

* **Pros:** Natural ecosystem extension since the Bitwarden Password Manager is already in use for personal/admin credentials; familiar interface.
* **Cons:** Violates the principle of separation of duties. Tying infrastructure machine secrets to the same platform and failure domain as personal identity management creates an unnecessary concentration of risk. Furthermore, it feels more like an extension of a password vault than a purpose-built CI/CD integration tool.

### Option D: Infisical

* **Pros:** Purpose-built for infrastructure injection and CI/CD pipelines; provides machine-identity tokens, full audit logs, secret versioning, and RBAC; native webhooks and integrations for Docker and Gitea Actions.
* **Cons:** Introduces a stateful application dependency (Postgres/Redis) that must be highly available for deployments to succeed.

## 3. Decision Outcome

### Update: Decision Rejected [2026-11-12]

**Status Change:** This decision was rejected during the implementation testing phase.

**Reasoning:** While Infisical successfully provided a centralized vault, injecting it into a Docker Compose GitOps flow introduced unacceptable fragility. It replaced a stateless encrypted file with a stateful dependency requiring Postgres and Redis. Furthermore, bootstrapping the Arcane deployment hook required storing the Infisical `CLIENT_ID` and `CLIENT_SECRET` in plaintext on the runner host. This effectively negated the security benefits compared to moving the SOPS master key to the runner, while massively increasing the administrative and infrastructure overhead.

**Superseded By:** Reverted to [ADR 004: Implementing SOPS as the Production Secrets Management](../adrs/adr-2026-04-10-004-implementing-sops-as-the-production-secrets-management.md) (See 2026-11-12 Amendment).
### Chosen Option

Option D — Infisical.

### Decision Statement

Deploy Infisical as the centralized secrets manager to issue machine-identity tokens to the Gitea Actions runner, injecting credentials dynamically into Arcane during deployment and entirely deprecating `.sops.env` files.

### Rationale

Infisical sits in the ideal "Tier 3" middle ground. It provides the API-driven, machine-token security and auditability missing from SOPS, without the brutal administrative overhead of HashiCorp Vault. Bitwarden Secrets Manager was strongly considered due to existing platform usage, but ultimately rejected to enforce a strict separation of duties between personal credential management and infrastructure state. Infisical will act as the dedicated secure enclave for all homelab automation.

## 4. Acceptance Criteria (measurable)

* AC-1: Infisical is deployed and accessible internally via Traefik with a valid Let's Encrypt certificate.
* AC-2: Infisical successfully authenticates administrators via Authentik (OIDC/SAML).
* AC-3: A Gitea Action pipeline successfully authenticates to Infisical using a Machine Identity token and retrieves a test secret.
* AC-4: All `.sops.env` files and the `sops-update.py` pre-commit hook are permanently removed from the `main` branch.

## 5. Test Plan & Artifacts

### Test Plan

1. Deploy the Infisical `docker-compose.yml` stack (including its Postgres and Redis dependencies).
2. Configure OIDC SSO via Authentik.
3. Create a test project in Infisical and generate a Machine Identity token.
4. Write a temporary Gitea workflow to fetch the secret and mask it in the runner logs to validate injection.

### Artifacts

| Artifact | Path/Link | Short description |
| --- | --- | --- |
| Infisical Stack | `docker/infisical/docker-compose.yml` | Stack definition for Infisical, Postgres, and Redis |
| Infisical Traefik Config | `docker/networking/traefik/config/traefik.yml` | Ingress routing definition |

## 6. Rollback Plan

*Since Infisical dictates deployment capability but not runtime stability, existing containers will not crash if Infisical fails.*

1. Restore the `sops-update.py` script and `.sops.env` files from Git history.
2. Revert the Gitea deployment workflows to rely on local `.env` file generation rather than API injection.
3. Spin down the Infisical stack.

**Estimated RTO:** ~15 minutes (to revert commits and rebuild local `.env` state).

## 7. Trade-offs, Risks and Mitigations

### Trade-offs

Moving from a stateless file encryption system (SOPS) to a stateful database-driven vault increases the infrastructure footprint and requires active database backups to prevent catastrophic credential loss.

### Identified Risks

* **Risk:** Infisical container crashes, preventing new deployments from fetching secrets. → **Mitigation:** Running containers cache their environment variables in Docker/Arcane. A vault outage only halts *new* pipeline deployments; it does not take down live production services.
* **Risk:** Total loss of the Infisical Postgres database. → **Mitigation:** Implement automated daily database dumps to the centralized NAS backup target.

## 8. Security Impact (CIA)

### Confidentiality

**High.** Secrets are entirely removed from the Git repository. The CI/CD runner is no longer entrusted with a master decryption key, utilizing only short-lived, narrowly scoped machine tokens.

### Integrity

**High.** Infisical provides immutable secret versioning and comprehensive audit logs detailing exactly which token accessed which secret at what timestamp.

### Availability

**Moderate.** Pipeline deployments now have a hard dependency on the uptime of the Infisical stack and its database.

## 9. Implementation Notes (sanitized)

* Infisical requires its own dedicated PostgreSQL and Redis instances for caching and state management.
* The initial deployment requires generating a secure symmetric encryption key (`ENCRYPTION_KEY`) and Auth Secret that must be backed up securely offline (e.g., in Bitwarden), as losing them permanently bricks the vault's contents.

## 10. Post-implementation Review

### Outcome Verification

**Date implemented:** [yyyy-mm-dd]
**Status:** [ Pass | Fail | Superseded | Deprecated | Partially Implemented ]

* **AC-1:** [Brief Outcome Description] [(yyyy-mm-dd)]
* **AC-2:** [Brief Outcome Description] [(yyyy-mm-dd)]
* **AC-3:** [Brief Outcome Description] [(yyyy-mm-dd)]
* **AC-4:** [Brief Outcome Description] [(yyyy-mm-dd)]

### Follow-ups

* Roll out recovery plan test (Database backup and restore):
* Owner: Marcos Tobon
* Date planned: [yyyy-mm-dd]


* Final review date:
* Scheduled for 2026-12-12

---

## Minimal ADR checklist

* [x] One-line decision statement present
* [x] Acceptance criteria defined and measurable
* [x] Test artifacts linked and reproducible
* [x] Rollback plan documented and timed
* [x] Confidence and review date set
* [ ] Rolled out and tested recovery plan

---

## Index Registration
> **Index Entry:** | 013 | 2026-11-12 | [Infisical As Secrets Management Solution](adrs/adr-2026-11-12-013-infisical-as-secrets-management-solution.md) | Proposed |
