# Sysadmin Log: Traefik Rollout

**Date:** 2026-11-11

**Report Time:** 10:58

**Category:** Maintenance

**Status:** Completed

---

## 1. Context & Problem Statement


**One-line summary:** Finalize Traefik Rollout, deploying all core services behind the Reverse Proxy and finalizing Observability routing.

**Background:** Following ADR-009 and the subsequent deployment of Traefik [2026-08-02], the testing and validation stages are considered finished. The Traefik deployment is now approved for full roll-out across the remaining core infrastructure, integrating SSO where applicable and finalizing internal DNS routing.


## 2. Architectural Decisions & Strategy

See [ADR-009](../adrs/adr-2026-08-02-009-traefik-as-reverse-proxy-with-dns-01-wildcard-certificates.md) and [Traefik Deployment Log](../operations/2026-08-02-traefik-implementation-and-deployment.md) for the foundational routing and proxy decisions.

## 3. Implementation & Execution

### Phase 1: Migrate Existing Services to Traefik

Following the success of the initial test-cases, the following services were migrated to Traefik:
- Dockhand
- Grafana (and Alloy)
- Meshcommander
- OPNsense (Dynamic configuration adjustments)
- IT-Tools (Removed hyphen from service and url for easier typing)

**Architectural Note on Wazuh:** The current commit completely omits Wazuh's SSL routing updates. This is done on purpose: recent changes in the homelab architecture, including a VLAN trunk port on the secondary NIC have brought about a reconsideration of the Wazuh architecture, which will result in a future project to completely restructure it. Thus, the change is noted, but the files aren't commited.

**Operational Note on Automation:** During this rollout, it was noted that the `traefik-compose.py` script produces damaging results in multi-container stacks. The decision was made to deprecate the script. Manual deployment proved that copying a baseline configuration and performing find-replace is highly efficient. Furthermore, manual intervention is often required to pinpoint specific ports and middlewares (e.g., UDP vs TCP routers) that an automated script cannot reliably infer. This is a procedural shift in deployment methodology, prioritizing stability over script-based templating.


### Phase 2: Integrate Traefik-enabled services with Authentik

With services secured via local SSL, those supporting SSO were connected to Authentik.

* **Grafana:** The SSO user `tobondev` was granted Administrator privileges by mapping group membership (`grafana-admins`) directly through the OIDC provider.
* **Immich:** The SSO connection utilizes role mapping via a simple Authentik expression (`return "admin" if user.ak_groups.filter(name="ImmichAdmins").exists() else "user"`). Since Authentik outright denies OIDC login requests to users lacking `ImmichUsers` membership, this binary fallback safely assumes any authenticated non-admin is a standard user.
* **Dockhand:** Dockhand's role-mapping in SSO is a paid feature. As such, an account was created, manually given admin access and then the built-in account was deleted.

**Fix: Traefik Certs Dumper**
During the Authentik integration, SSL certificates failed to update for the Authentik container. The root cause was a permissions mismatch: Authentik runs rootless (UID 1000) and could not read the certificates output by the root-owned `traefik-certs-dumper`. This was resolved by appending the post-hook option `--post-hook "chown -R 1000:1000 /certs"` to the certs-dumper command in the Traefik `docker-compose.yml`, restoring automated certificate propagation.

### Phase 3: Update Observability & Traefik Port Definitions

To properly route telemetry and logs securely, the Traefik port definitions were expanded to accommodate Grafana Alloy.

* Added the necessary UDP/TCP routers in Traefik to handle Alloy traffic.
* Updated the Ansible templates (`linux_alloy_config.j2`) and encrypted secrets (`secrets.sops.yml`) to ensure deployed endpoints communicate with the newly proxied Alloy ingress.

## 4. Outcome & Future Considerations

* **Result:** All core management and observability services (Grafana, Dockhand, IT-Tools, Meshcommander) are now securely routed through Traefik with valid SSL.
* **Result:** Authentik certificate renewal is functioning correctly without requiring root access to the container.
* **Result:** Alloy telemetry routing is successfully proxied and deployed via Ansible.

### Next Steps

* [x] **Completed:** Traefik rollout and Authentik integration across core services.
* [x] **Completed:** Deprecated the unreliable `traefik-compose.py` deployment script.
