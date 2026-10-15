# ADR 010: Authentik as Identity Provider

**File:** adr-2026-10-13-010-authentik-as-identity-provider.md
**Title:** Authentik as Identity Provider
**Date:** 2026-10-13
**Status:**  Accepted
**Decider(s):** Marcos Tobon
**Owner:** @tobondev
**Confidence:** High
**Review-by:** 2026-11-11

---

## 1. Context and Problem Statement

### One-line summary

Deploy Authentik as the central login system (SSO) for the homelab, pairing it with Traefik to offer secure OpenIDConnect SSO, as well as trusted TLS certificates for LDAP-based authentication.

### Background

After deploying Traefik [2026-08-02], the next step was to centralize authentication. Before this, each service used its own authentication system, plenty of which were based on environment variables. This means security is highly variable and account sprawl becomes a concern as the number of services grows.

## 2. Considered Options

### Summary Table

| Option ID | Short Name | Description | Security Impact | Cost | Complexity | Time to Implement |
|-----------|------------|-------------|----------------|------|------------|-------------------|
| A | Authelia | Use Authelia as Identity Provider |*High* | *Zero* | *High* | *1–2 weeks* |
| B | Keycloak | Use Keycloak as Identity Provider | *High* | *Zero* | *Medium* | *1–2 weeks* |
| C | Authentik | Use Authentik as Identity Provider | *High* | *Zero* | *Low* | *1 week* |

### Option A: Authelia

- **Pros:** Good Documentation, ample support for identity federation, support for Coditional Access, MFA, SSO, Oauth,OpenIDConnect, SAML.
- **Cons:** No support for Application Proxies, lack of GUI to configure applications, no self-service options for account provisioning

### Option B: Keycloak

- **Pros:** Supported by Red Hat, better brand recognition (resume value), Support for Conditional Access, MFA, SSO, OAuth, OpenIDConnect, SAML, self-service provisioning
- **Cons:** No support for LDAP, requiring federation, no support for PAM, no built-in support for `forwardAuth`.

### Option C: Authentik

- **Pros:**Support for Conditional Access, MFA, SSO, OAuth, OpenIDConnect, SAML, self-service provisioning, LDAP, PAM and `forwardAuth`
- **Cons:** Brand recognition lags behind Keycload, lowering portfolio value. Less established in the enterprise space.

## 3. Decision Outcome

### Chosen Option
Option C — Authentik.

### Decision Statement

Deploy Authentik as the central login system (SSO) for the homelab, pairing it with Traefik to offer secure OpenIDConnect SSO, as well as trusted TLS certificates for LDAP-based authentication.

### Rationale

* **Pros:** Abundant documentation available, including Christian Lempa's series, which focuses specifically in Traefik integration, making it a good fit for the current infrastructure. Simple to configure, broad support for LDAP and SSO, extensive feature set in the free edition.
* **Cons:** Lower resume value compared to Keycloak.
* **Neutral:** Like all other providers, it introduces a Single Point Of Failure (SPOF).

## 4. Acceptance Criteria (measurable)

- AC-1: Every application currently deployed integrates successfully with Authentik.
- AC-2: LDAP authentication is implemented without disabling MFA requirements.
- AC-3: Traefik's `forwardAuth` proxy successfully centralizes authentication for applications that don't support OIDC or LDAP.
- AC-4: SSL Certificates for LDAPS auto-renew without the need for manual intervention.

## 5. Test Plan & Artifacts

### Test Plan
1. Log into HomeAssistant and Dockhand via OIDC. This should prompt MFA. Validates `AC-1`. 
2. Log into Jellyfin and OPNsense using LDAP. There should be no MFA prompt. Validates `AC-2`.
3. Open a Private window and visit the OPNsense and Traefik URLs and validate they are intercepted by the `forwardAuth` proxy. Validates `AC-3`.
4. Check file ownership and permissions for the certificates dumped by `traefik-certs-dumper` in the shared directory and ensure the Authentik worker (UID 1000) can read them without root access.

### Artifacts

| Artifact | Path/Link | Short description |
|---------|------|---------|
| Authentik `forwardAuth` configuration | `../../docker/networking/traefik/dynamic_conf/authentik.yml` | Traefik `forwardAuth` proxy definition for Authentik-based application authentication |
| `traefik-certs-dumper` UID/GID Config | `../../docker/networking/traefik/docker-compose.yml` | Docker Compose configuration detailing use of OVERRIDE_UID and OVERRIDE_GID variables |
| IT Tools `forwardAuth` screenshot | `../artifacts/authentik/2026-10-11_Authentik_Proxy_Provider_IT-Tools_SSO_Screen.png` | Forward Auth Proxy intercepts ITTools service and requires authorization |
| OPNsense `forwardAuth` screenshot | `../artifacts/authentik/2026-10-11_Authentik_Proxy_Provider_OPNsense_SSO_Screen.png` | Forward Auth Proxy intercepts OPNsense and requires authorization |
| Authentik MFA Prompt | `../artifacts/authentik/2026-10-11_Authentik_MFA_Prompt.png` | Authentik MFA Prompt for OIDC, proving it still is enforced outside of LDAP |

## 6. Rollback Plan

Rollback falls into one of two categories: `forwardAuth` services and everything else.

Because the SPOF is recognized as a concern during the initial stages of deployment, no local users will be deleted at this time, to ensure there is a fallback in case Authentik fails or needs to be rolled back. For services where users were synced, a new local admin user was created as a fallback.

### `forwardAuth` services

1. Revert the Docker Compose file to the previous state, before Authentik rollout, from git revision history.
2. Revert the environment file to the previous state. This should restore local authentication for those services that had it beforehand.
3. Restart the service with `docker compose down && docker compose up -d --force-recreate`.

### Everything else

1. Revert middleware file to previous status if it includes `forwardAuth` protection.
2. Enable local accounts and reprovision passwords. If locked out, see 3. 
3. Log-in to the service with local user.
4. Reset other user accounts to local authentication if any exist.

**Estimated RTO:** 30-40 minutes.

## 7. Trade-offs, Risks and Mitigations

### Trade-offs

SPOF is an accepted trade-off to simplify Identity and Access Management.

### Identified Risks
- **Risk:** Loss of access to services due to Authentik failure → **Mitigation:** Preserve LocalAdmin accounts for emergency access and service restoration.

## 8. Security Impact (CIA)

### Confidentiality

Credentials are protected in-transit inside the LAN: LDAPS for Authentication, HTTPS for backend services behind Traefik, or internal routing inside the docker network. No plaintext credentials are exposed in the LAN.

### Integrity

Centralized identity ensures that access controls can be centralized and managed, allowing account passwords to be rotated effortlessly, managing tokens and sessions and deauthorizing services and accounts on demand.

### Availability

Availability is a trade-off in the current deployment model for this architecture. Authentik now joins Traefik as a single point of failure for all SSO-dependent services. Possible mitigations include future HA projects (Kubernetes, Proxmox clusters).

## 9. Implementation Notes (sanitized)



## 10. Post-implementation Review

### Outcome Verification

**Date implemented:** 2026-10-10
**Status:** Pass

- **AC-1:** Pass [2026-10-10]
- **AC-2:** Pass [2026-10-10]
- **AC-3:** Pass [2026-10-10]
- **AC-4:** Pass [2026-10-10]

### Follow-ups

- Roll out recovery plan test:
	- Owner: Marcos Tobon
	- Date planned: COMPLETED. [2026-10-15]. This recovery exercise was the basis of the rollback procedure.

- Final review date:
	- Scheduled for 2027-01-15.

---
## Minimal ADR checklist
- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [x] Rolled out and tested recovery plan

---
## Index Registration
> **Index Entry:** | 010 | 2026-10-13 | [Authentik as Identity Provider](adrs/adr-2026-10-13-010-authentik-as-identity-provider.md) | Implemented |
