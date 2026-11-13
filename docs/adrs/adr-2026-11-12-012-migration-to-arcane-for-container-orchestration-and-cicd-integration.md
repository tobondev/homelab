# ADR 012: Migration to Arcane for Container Orchestration and CI/CD Integration

**File:** adr-2026-11-12-012-migration-to-arcane-for-container-orchestration-and-cicd-integration.md
**Title:** Migration to Arcane for Container Orchestration and CI/CD Integration
**Date:** 2026-11-12
**Status:** Accepted
**Decider(s):** Marcos Tobon
**Owner:** @tobondev
**Confidence:** High
**Review-by:** 2026-12-12

---

## 1. Context and Problem Statement

### One-line summary

Replace the existing DockHand container management system with Arcane to establish a fully open-source orchestration layer with native OIDC, RBAC, and CI/CD pipeline integration, while preserving declarative YAML file binding.

### Background

The homelab infrastructure has historically relied on DockHand for container management. While functional, DockHand is source-available (not fully open-source) and restricts critical security features, such as Role-Based Access Control (RBAC), behind an Enterprise license. As the infrastructure evolves to support a formalized CI/CD pipeline (driven by Gitea Actions), the orchestration layer must support programmatic deployments, security scanning, and granular access control via Authentik (OIDC). Furthermore, the chosen orchestrator must rely on direct YAML file bindings rather than an internal database to ensure configuration portability and prevent vendor lock-in.

## 2. Considered Options

### Summary Table

| Option ID | Short Name | Description | Security Impact | Cost | Complexity | Time to Implement |
| --- | --- | --- | --- | --- | --- | --- |
| A | DockHand | Keep the existing DockHand deployment. | Medium | High (Licensing) | Low | 0 weeks |
| B | Komodo | Deploy Komodo for advanced CI/CD and orchestration. | High | Zero | Medium | 1 week |
| C | Dockage | Migrate to Dockage for lightweight YAML-bound management. | Medium | Zero | Low | 1 < week |
| D | Arcane | Migrate to Arcane for fully open-source orchestration with OIDC/RBAC. | High | Zero | Low | < 1 week |

### Option A: DockHand (Status Quo)

* **Pros:** Already deployed and operational; familiar interface.
* **Cons:** Source-available licensing; RBAC is locked behind a paid Enterprise tier; limited native integration capabilities for the newly established Gitea CI/CD pipeline.

### Option B: Komodo

* **Pros:** Extremely powerful feature set; robust CI/CD capabilities and native scaling features.
* **Cons:** State is heavily database-driven rather than relying on direct file-system YAML binding. This complicates portability, breaks the established GitOps direct-file workflow, and introduces a higher RAM/CPU overhead.

### Option C: Dockage

* **Pros:** Lightweight; respects direct YAML file bindings (excellent for portability).
* **Cons:** Lacks the deep enterprise-grade security features out-of-the-box (like comprehensive OIDC mapping, RBAC, and native security scanning) required for the next phase of the infrastructure evolution.

### Option D: Arcane

* **Pros:** Fully open-source; features native OIDC integration, RBAC, security scanning, and CI/CD webhooks; utilizes direct YAML file binding for ultimate portability and GitOps synchronization.
* **Cons:** Requires a migration window to transfer existing container management contexts from DockHand.

## 3. Decision Outcome

### Chosen Option

Option D — Arcane.

### Decision Statement

Decommission DockHand and deploy Arcane as the centralized Docker orchestration and management UI to securely manage container state and execute deployments triggered by Gitea Actions.

### Rationale

Arcane offers the exact intersection of features required for the new GitOps control plane. It provides the enterprise security features (OIDC via Authentik and RBAC) that DockHand paywalls, without abandoning the direct `docker-compose.yml` file-binding architecture that ensures our repositories remain the ultimate source of truth. Komodo was rejected due to its database-centric state management and resource overhead, making Arcane the most portable and efficient choice.

## 4. Acceptance Criteria (measurable)

* AC-1: Arcane is deployed and accessible via Traefik with a valid Let's Encrypt SSL certificate.
* AC-2: Arcane successfully authenticates users via OpenID Connect (OIDC) through Authentik, mapping the administrator group correctly.
* AC-3: Existing infrastructure containers are successfully identified and managed by Arcane via direct YAML file binding.
* AC-4: DockHand is fully decommissioned and its container/volumes removed.

## 5. Test Plan & Artifacts

### Test Plan

1. Deploy the Arcane `docker-compose.yml` stack.
2. Configure the OIDC provider in Authentik and map it to Arcane's authentication settings.
3. Point Arcane to the existing `docker/` directory structure to validate it can parse and manage the current Compose files without mutating them.
4. Stop and remove the DockHand container.

### Artifacts

| Artifact | Path/Link | Short description |
| --- | --- | --- |
| Arcane Stack | `docker/observability/arcane/docker-compose.yml` | Deployment configuration for the Arcane orchestrator |
| Traefik Routing | `docker/networking/traefik/config/traefik.yml` | Ingress routing for the Arcane UI |

## 6. Rollback Plan

*Since the Docker daemon runs containers independently of the management UI, rolling back orchestrators carries zero risk to running services.*

1. Spin down the Arcane container (`docker compose down`).
2. Spin the DockHand container back up from its existing configuration.
3. Update Traefik to route traffic back to the DockHand port.

**Estimated RTO:** < 2 minutes.

## 7. Trade-offs, Risks and Mitigations

### Trade-offs

Direct YAML file binding requires strict file-system permissions and prevents Arcane from managing multi-node swarm states as elegantly as a database-driven orchestrator (like Komodo), but this is an acceptable trade-off for a single-node homelab prioritizing GitOps portability.

### Identified Risks

* **Risk:** CI/CD pipeline triggers simultaneous deployment conflicts if Gitea Actions and the Arcane UI attempt to modify the same YAML file. → **Mitigation:** Enforce a strict GitOps policy: Arcane is used strictly for state visibility, manual restarts, and logs. All configuration mutations must originate from a Gitea commit.

## 8. Security Impact (CIA)

### Confidentiality

**High.** Transitioning from a single-admin model to Authentik OIDC with RBAC ensures granular control over who can view environment variables and container logs.

### Integrity

**High.** Direct YAML binding ensures the configuration on disk (pulled from Gitea) remains the absolute source of truth, preventing the orchestrator's database from drifting from the repository state.

### Availability

**High.** The management UI is decoupled from container execution. If Arcane goes offline, all infrastructure services continue routing and functioning normally.

## 9. Implementation Notes (sanitized)

* Arcane requires mounting the Docker socket (`/var/run/docker.sock`) to manage containers. This is standard but necessitates strict OIDC perimeter defense via Traefik/Authentik to prevent unauthorized socket access.
* Ensure the `PUID` and `PGID` mapped to the Arcane container have read/write access to the `docker/` configuration directories so it can successfully parse the bounded YAML files.

## 10. Post-implementation Review

### Outcome Verification

**Date implemented:** 2026-11-12
**Status:** Pass

* **AC-1:** Arcane deployed and routing correctly via Traefik. (2026-11-12)
* **AC-2:** Authentik OIDC successfully integrated and enforcing RBAC. (2026-11-12)
* **AC-3:** YAML files successfully bound and containers adopted by Arcane. (2026-11-12)
* **AC-4:** DockHand container and orphaned volumes successfully pruned. (2026-11-12)

### Follow-ups

* Integrate Arcane webhook triggers into the Gitea Actions runner pipeline (Phase 3 of CI/CD rollout):
* Owner: Marcos Tobon
* Date planned: 2026-11-25


* Final review date:
* Scheduled for 2026-12-12



---

## Minimal ADR checklist

* [x] One-line decision statement present
* [x] Acceptance criteria defined and measurable
* [x] Test artifacts linked and reproducible
* [x] Rollback plan documented and timed
* [x] Confidence and review date set
* [x] Rolled out and tested recovery plan

---
## Index Registration
> **Index Entry:** | 012 | 2026-11-12 | [Migration to Arcane for Container Orchestration and CI/CD Integration](adrs/adr-2026-11-12-012-migration-to-arcane-for-container-orchestration-and-cicd-integration.md) | Proposed |



