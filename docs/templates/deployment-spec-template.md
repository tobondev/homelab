# Deployment Spec: {{RAW_TITLE}}

**ID:** dep-{{CURRENT_DATE}}-{{SEQ_ID}}  
**Owner:** {{OWNER_HANDLE}}  
**Status:** [ Planned | In Progress | Active | Decommissioned ]  
**Lifecycle Class:** [ Ephemeral / Proof-of-Concept | Staged Testing | Temporary Lab ]  
**Target Expiry / Review Date:** [YYYY-MM-DD]  

---

## 1. Scope & Objective

### Objective

[Brief description of the service being deployed and the specific engineering problem it solves.]

### Boundary & Lifecycle Criteria

* **Deployment Lifespan:** [e.g., 30-day trial period / Ephemeral VM test]
* **Teardown Trigger:** [e.g., Completion of permission testing / Trial expiration]
* **Out-of-Scope:** [List explicit boundaries, e.g., No public WAN publishing, no email parsing integration]

---

## 2. Integration Architecture & RBAC

### Network & Authentication Flow

* **Target System:** [e.g., Zoho Desk (SaaS)]
* **Identity Source:** [e.g., On-premise Active Directory via LDAP/ADSync / Entra ID SAML]
* **Network Path:** [e.g., AD VLAN -> Outbound 443 via OPNsense NAT]
* **Service Account / Auth Method:** [e.g., `svc_zohodesk` (Least privilege, Read-only to `OU=Users`)]

### Identity & Permission Mapping

| AD Group / Principal | Zoho Desk Role | Zoho Desk Profile | Permitted Scope / Permissions |
| :--- | :--- | :--- | :--- |
| `GG-Helpdesk-Agents` | Agent | Helpdesk Staff | Ticket management, status updates, internal notes |
| `GG-Domain-Users` | End User | Portal User | Ticket creation, view own tickets only |
| `GG-Helpdesk-Admins` | Administrator | Desk Admin | Department routing, SLA configuration, user sync |

---

## 3. Prerequisites & Environment State

### Infrastructure Prerequisites

- [ ] Service account created with minimal required read attributes.
- [ ] Network egress/firewall rules verified (Port 443 outbound).
- [ ] DNS resolution functional for cloud endpoint.
- [ ] Baseline snapshot created for on-premise infrastructure (`[Target VM Name]`).

### Secrets & Configuration Hooks

| Variable / Secret Key | Vault / Storage Location | Purpose |
| :--- | :--- | :--- |
| `ZOHO_CLIENT_ID` | `[Internal Secrets Store / Keyring]` | API authentication |
| `SVC_AD_BIND_PASS` | `[Internal Secrets Store / Keyring]` | Directory synchronization read access |

---

## 4. Execution & Verification

### Phase 1: Directory Integration

1. **[Integration Step 1]:** [Action taken, e.g., Configure AD sync connector or SAML SSO]
2. **[Integration Step 2]:** [Attribute mapping verification]

### Phase 2: Role Assignment & Portal Configuration

1. **[Configuration Step 1]:** [Department and team setup]
2. **[Configuration Step 2]:** [Ticket assignment rules and portal security limits]

### Verification & Test Matrix

| Test ID | Scenario | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TEST-01** | End-user submits ticket via portal | Account created under `Portal User`, ticket routed | | [Pass/Fail] |
| **TEST-02** | End-user attempts agent dashboard access | Access denied (403 or redirect to portal) | | [Pass/Fail] |
| **TEST-03** | Agent updates ticket status and reassigns | Ticket updated; audit log records agent identity | | [Pass/Fail] |
| **TEST-04** | Agent attempts administrative department edit | Access denied | | [Pass/Fail] |

---

## 5. Teardown & Decommissioning

*Execute these steps to return the infrastructure to its pre-deployment baseline.*

1. **Identity Revocation:** Disable and delete `svc_zohodesk` service account from Active Directory.
2. **Access Revocation:** Revoke API keys, tenant tokens, and enterprise application registrations.
3. **State Rollback:** Revert VM snapshot if local agent software was installed:
   ```bash
   # Snapshot rollback command if applicable

```

4. **Directory Cleanup:** Remove any staging OUs, test attributes, or test security groups.

---

## 6. Artifacts & Session Log

| Artifact Name | Path / Repository Link | Description |
| --- | --- | --- |
| Sync Script / Config | `configs/zoho-sync-config.json` | Sanitized sync configuration schema |
| Audit Export | `docs/artifacts/zoho-perm-audit.csv` | Evidence of permission separation |

### Operational Notes

* [Record technical quirks, rate limits, or integration hurdles encountered during deployment]
