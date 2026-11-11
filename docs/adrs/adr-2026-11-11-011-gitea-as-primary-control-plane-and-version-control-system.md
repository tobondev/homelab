# ADR 011: Gitea as Primary Control Plane and Version Control System

**File:** adr-2026-11-11-011-gitea-as-primary-control-plane-and-version-control-system.md
**Title:** Gitea as Primary Control Plane and Version Control System
**Date:** 2026-11-11
**Status:** Proposed
**Decider(s):** Marcos Tobon
**Owner:** @tobondev
**Confidence:** High
**Review-by:** 2026-12-01

---

## 1. Context and Problem Statement

### One-line summary

Migrate the primary Git remote to a self-hosted Gitea instance to act as a private CI/CD control plane, while utilizing push-mirroring to maintain GitHub as a sanitized, read-only public portfolio.

### Background

As the homelab infrastructure has grown, a need for a GitOps workflow has surfaced. The current workflow involves local commits, manual deployment of projects and .env files using `rsync` and `ssh`, resulting in configuration drifts. While a recent custom pre-commit hook (`sops-update.py`) solved the problem of accidentally forgetting to create or commit updated `.sops.env` files, this stop-gap solution highlights the lack of an automated CI/CD pipeline and a centralized execution environment capable of safely fetching credentials and deploying containers. The infrastructure now requires a strict separation of concerns: a private control plane for execution, automated secrets injection, and iteration, alongside a public display window for finalized states.

## 2. Considered Options

### Summary Table

| Option ID | Short Name | Description | Security Impact | Cost | Complexity | Time to Implement |
|-----------|------------|-------------|----------------|------|------------|-------------------|
| A | GitHub (SaaS) | Continue using GitHub via separate private/public repositories. | Medium | Zero | Medium | ~1 week |
| B | GitLab CE | Deploy self-hosted GitLab Community Edition | Medium | Zero | *High* | ~2 weeks |
| C | Gitea | Deploy self-hosted Gitea with built-in actions | *High* | Zero | Medium | ~2 weeks |

### Option A: GitHub

- **Pros:** Industry standard; zero hosting overhead; GitHub Actions is highly mature.

- **Cons:** Cannot be self-hosted. It does not support granular public/private differentiation within a single repository. Achieving the desired separation would require maintaining two completely separate repositories (one private for CI/CD, one public) and manually synchronizing them, creating significant administrative friction.

### Option B: GitLab

- **Pros:** The enterprise standard for self-hosted GitOps; incredibly robust built-in CI/CD pipelines; excellent container registry integration.

- **Cons:** Extremely resource-intensive. An initial deployment test revealed an unacceptably high RAM baseline for a single-user homelab environment. It is vastly over-engineered for the current use-case.

### Option C: Gitea

- **Pros:** Extremely lightweight and fast (written in Go); features built-in Actions that are highly compatible with GitHub Actions workflows; natively supports automated push-mirroring to external remotes like GitHub; integrates cleanly with the existing Traefik/Authentik stack.

- **Cons:** Smaller community ecosystem compared to GitLab; Gitea Actions is a newer feature and may require minor syntax workarounds compared to native GitHub Actions.

## 3. Decision Outcome

### Chosen Option

Option C — Gitea.

### Decision Statement

Deploy Gitea as the primary, self-hosted version control system and CI/CD engine. Configure Gitea to execute automated deployment pipelines internally, and set up a restricted Push Mirror to automatically synchronize the `main` branch to GitHub for portfolio presentation.

### Rationale

Gitea perfectly bridges the gap between resource efficiency and operational capability. It resolves the public/private repository conflict by allowing the entire development lifecycle (feature branches, WIP commits, failed pipeline runs) to remain strictly local. By relying on squash-merges into `main`, the public GitHub repository receives only clean, semantic commits representing successful infrastructure states via Gitea's native push-mirroring. GitLab was rejected purely on hardware inefficiency, and GitHub was rejected due to its lack of local execution and single-repo visibility controls.

## 4. Acceptance Criteria (measurable)

- AC-1: Gitea is accessible internally via a Traefik-proxied domain with a valid Let's Encrypt wildcard SSL certificate.
- AC-2: Gitea successfully authenticates users via OpenID Connect (OIDC) through Authentik.
- AC-3: SSH passthrough is functional via a Traefik TCP router, allowing standard Git push/pull operations over SSH.
- AC-4: A push mirror is established and successfully synchronizes commits from the local `main` branch to the public GitHub repository automatically.

## 5. Test Plan & Artifacts

### Test Plan

1. Configure a test repository and its corresponding upstream GitHub mirror.
2. Validate SSH routing by pushing a test commit to the local Gitea instance over the configured SSH port.
3. Validate the push-mirror by monitoring the GitHub repository to ensure the test commit on test repository is synchronized without manual intervention.
3. Validate Identity and Access Management by authenticating into the Gitea web interface using the Authentik OIDC flow.

### Artifacts

| Artifact | Path/Link | Short description |
|---------|------|---------|
| Gitea Docker Compose | `docker/gitea/docker-compose.yml` | Stack Definition for Gitea and Database | 
| Traefik TCP Router Config | `docker/networking/traefik/config/traefik.yml`  | Traefik configuration enabling SSH passthrough for Git operations | 
| OIDC Login Screenshot | `docs/artifacts/gitea/[PLACEHOLDER]`  | Screenshot depicting successful OIDC login | 

## 6. Rollback Plan

1. Revert local Git remote origin from the local Gitea URL back to the public GitHub repository URL using `git remote set-url origin <github-url>`.
2. Spin down the Gitea docker compose stack using `docker compose down`
3. Remove the Traefik TCP router definitions for the SSH passthrough to prevent dead routing using `git restore docker/networking/traefik/config/traefik.yml`

**Estimated RTO:** ~10 minutes.

## 7. Trade-offs, Risks and Mitigations

### Trade-offs

Increased local storage footprint and maintenance overhead compared to relying purely on a SaaS provider for version control and CI/CD pipelines.

### Identified Risks

- **Risk:** Host server failure prevents pushing or accessing code locally → **Mitigation:** Code remains highly available locally on developer workstations; the GitHub mirror serves as a continuous off-site backup for the `main` branch.

- **Risk:** Accidental exposure of internal infrastructure secrets to the GitHub mirror. → **Mitigation:** Strict adherence to squash-merging feature branches, use of .gitignore and sops for .env files. No additional risk compared to current architecture.

## 8. Security Impact (CIA)

### Confidentiality

Work-in-progress code, failed CI/CD execution logs, and experimental infrastructure branches remain strictly within the homelab network, entirely isolated from the public portfolio.

### Integrity

Gitea branch protections combined with squash-merging enforces a clean commit history on the public mirror, with the additional benefit of un-squashed branches as local archives.

### Availability

Relies directly on homelab uptime and Traefik routing. Mitigated by the decentralized nature of Git (local caches) and the GitHub push mirror.

## 9. Implementation Notes (sanitized)

- SSH passthrough requires defining a dedicated TCP entrypoint in Traefik's static configuration (e.g., port 2222) and routing it directly to the Gitea container's port 22.

- OIDC integration requires creating an OAuth2 provider in Authentik and configuring Gitea's authentication sources to map the provider's discovery URL and client credentials.

## 10. Post-implementation Review

### Outcome Verification

**Date implemented:** [yyyy-mm-dd]
**Status:** [ Pass | Fail | Superseded | Deprecated | Partially Implemented ]

- **AC-1:** [Brief Outcome Description] [(yyyy-mm-dd)]
- **AC-2:** [Brief Outcome Description] [(yyyy-mm-dd)]
- **AC-3:** [Brief Outcome Description] [(yyyy-mm-dd)]
- **AC-4:** [Brief Outcome Description] [(yyyy-mm-dd)]

### Follow-ups
- Roll out recovery plan test:
	- Owner: Marcos Tobon
	- Date planned: [2026-11-22]

- Final review date:
	- Scheduled for [2026-12-01]

---
## Minimal ADR checklist
- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [ ] Rolled out and tested recovery plan

---
## Index Registration
> **Index Entry:** | 011 | 2026-11-11 | [Gitea as Primary Control Plane and Version Control System](adrs/adr-2026-11-11-011-gitea-as-primary-control-plane-and-version-control-system.md) | Proposed |
