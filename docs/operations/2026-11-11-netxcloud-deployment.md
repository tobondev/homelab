# Sysadmin Log: Netxcloud Deployment

**Date:** 2026-11-11

**Report Time:** 16:17

**Category:**  Storage

**Status:** Completed

---

## 1. Context & Problem Statement


**One-line summary:** Deploy Nextcloud as a tenant service in the lab infrastructure.

**Background:** As part of the services to be run for personal use, Nextcloud was chosen as a cloud hosting platform. This is not a core infrastructure service in the homelab and doesn't have an accompanying ADR. It is documented here because its addition requires modifying the Traefik proxy, representing a visible change to the lab configuration.


## 2. Architectural Decisions & Strategy

### Decision 1: Nextcloud as a tenant, not a core service.

**Decision:** Deploy Nextcloud in the existing infrastructure strictly for personal use, rather than as a core service for file synchronization.
**Rationale:** The homelab infrastructure operates entirely on Git and Markdown, requiring no office suite or mobile clients for file management.


## 3. Implementation & Execution

### Phase 1:

### Phase 1: Stack Deployment and Traefik Integration

*   **Core Stack:** Deployed Nextcloud alongside MariaDB, Redis (Alpine), and Collabora CODE via a Docker Compose stack.
*   **Network Isolation:** Placed backend services (MariaDB, Redis) on an isolated internal `nextcloud` network, exposing only the Nextcloud and Collabora containers to the external `proxy_web` Traefik mesh.
*   **CalDAV/CardDAV Auto-Discovery:** Implemented a mandatory Traefik middleware (`nextcloud-dav`) utilizing regex to permanently redirect `^/.well-known/(card|cal)dav` requests to `/remote.php/dav/`.
*   **Collabora Integration (WebSockets & SSL):**
    *   Enabled a privileged container (Kit jail) for performance and explicitly disabled internal SSL generation (`DONT_GEN_SSL_CERT=true`), passing SSL termination responsibilities to Traefik.
    *   Configured a dedicated Traefik middleware (`collabora-headers`) to pass required custom request headers for WebSocket connection upgrades (`Upgrade=websocket`, `Connection=Upgrade`).

## 4. Outcome & Future Considerations

*   **Result:** Nextcloud and Collabora are successfully deployed as tenant services, isolated from core infrastructure but seamlessly integrated into the Traefik ingress routing.
*   **Result:** Advanced routing requirements (CalDAV auto-discovery, WebSocket upgrades) are fully handled at the proxy level via Traefik middlewares.

### Next Steps

- [x] **Completed:** Finalized Nextcloud tenant deployment and merged to main.
