# ADR 009: Traefik as Reverse Proxy with DNS-01 Wildcard Certificates

**File:** adr-2026-08-02-009-traefik-as-reverse-proxy-with-dns-01-wildcard-certificates.md

**Title:** Traefik as Reverse Proxy with DNS-01 Wildcard Certificates

**Date:** 2026-08-02

**Status:** Implemented

**Decider(s):** Marcos Tobon

**Owner:** @tobondev

**Confidence:** High

**Review-by:** 2026-08-14

---

## 1. Context and Problem Statement

**One-line summary:** Implement Traefik as a Unified Reverse Proxy Solution, using a wildcard certificate base via DNS-01 Challenge to secure internal traffic and implement internal DNS Resolution.

**Background:**  The current homelab architecture features plaintext communication over HTTP in most services, while the most critical ones use self-signed certificates. Both approaches were deemed sufficient at the time, considering services are separated in a trusted zone, and prioritizing further learning and deployment. As the number of services increases, and more of them are security-focused, the number of self-signed certificates increases, and creating exceptions or trusted certificates is no longer a sustainable approach. Additionally, as the service count continues to increase, maintaining a clear record of which service is mapped to which IP and port combination has become a time-consuming endeavour. Traefik is designed to resolve both issues, doubling as a Reverse Proxy and SSL Manager.


## 2. Considered Options

### 2.1 Summary Table

| Option ID | Short Name | Description | Security Impact | Cost | Complexity | Time to Implement |
|-----------|------------|-------------|----------------|------|------------|-------------------|
| A | `nginx` | Implement Nginx Proxy Manager with Certbot and Let's Encrypt  | High | Free | Medium | 1-2 Days |
| B | `caddy` | Implement Caddy as the Reverse Proxy Web Server | High | Free | Low | 1-2 days |
| C | `Traefik` | Implement Traefik as a Docker-Native Reverse Proxy and SSL Manager | High | Free | High | 1-2 days |


### 2.2 Detailed Option Descriptions

---

#### Option A: *nginx*

**Description:** Nginx Proxy Manager wraps Nginx in a web interface. This WebUI is the main configuration point, allowing a point-and-click experience to create new proxy hosts, generating the necessary nginx config files behind the scenes.


- **Pros:**
  - *WebUI for user-friendly service overview*
  - *Ample documentation available*
  - *Uses standard technologies behind the scenes (certbot, acme, nginx)*
- **Cons:**
  - *Requires manual configuration via WebUI*
  - *New host can't be added in an automated fashion*
  - *No Native Docker Integration*

---

#### Option B: *Caddy*

**Description:** Caddy is a web server written in Go that does automatic HTTPS by default. It automatically requests and renews certificates for every domain defined. It features a simple caddyfile format for configuring new services.

- **Pros:**
  - *Simplest configuration structure out of all the options*
  - *Handles SSL Certificate generation and renewal behind the scenes with no configuration required*
- **Cons:**
  - *No Native Docker Integration (relies on third-party plugins)*
  - *No Web UI*
  - *Fewer learning and debugging resources available*
  - *No native support for DNS-01 Challenge Certificate Issuance*

---

#### Option C: *Traefik*

**Description:** Traefik is a reverse proxy solution built specifically with containerization in mind; not only does it run seamlessly as a docker compose stack, but it is able to watch the docker socket for new containers once they spin up. Once configured, it never needs to be touched to add new services.

- **Pros:**
  - *Native Docker Integration*
  - *Responsive Certificate Generation*
  - *Features a "watch" model that scans for new docker services in the network*
  - *Handles SSL Certificate generation and renewal behind the scenes with no configuration required*
  - *Native Support for DNS-01 Challenge Certificate Issuance*
- **Cons:**
  - *Web UI is mostly for overview*
  - *Requires rewriting existing Docker Compose files*
  - *Requires access to the Docker Socket (mitigations available)*
  - *Most complex configuration out of the three options considered*

---

## 3. Decision Outcome

**Chosen option:** Option C — `Traefik`.

**Decision statement:** Implement Traefik as the Reverse Proxy and SSL Manager for existing infrastructure.

**Rationale:**

**Pros:**
* Featuring Native Docker Integration immediately puts Traefik high on the candidate list. Most of the services currently running in the homelab are dockerized.
* Traefik supports proxying to IPs outside of the docker socket, meaning it can easily continue to serve as the SSL and Reverse Proxy solution as the homelab scales. 
* The documentation for it is abundant, if slightly obtuse, and the community support is the second largest in the list (topped only by nginx).
**Cons:**
* Traefik is the most difficult service to set up, and it requires rewriting a considerable amount of docker compose stacks.
* As with any of the options considered, the model requires rethinking the firewall isolation rules and moving access controls up to the proxy layer.


## 4. Acceptance Criteria (measurable)

- AC-1: All services are migrated and accessible within the trusted LAN.
- AC-2: Services are, by default, inaccessible in other networks.
- AC-3: Access Control Rules must allow for individual service authorization for devices and services cross-vlan, comparable to the current firewall + pinhole rule model.
- AC-4: Docker Compose Files files are version controlled.

## 5. Test Plan & Artifacts (links + short summary)

**Test plan (high level):**

1. Get Cockpit self-signed certificate information using openssl.
openssl s_client -showcerts -connect {SERVER_IP}:9090
2. Get Cockpit wildcard certificate information using openssl.
openssl s_client -showcerts -connect {SERVER_COCKPIT_URL}:443
3. Updating the cloudflare tunnel endpoints for the services allows external access on the same URLs.
4. Validate web-browser returns a valid certificate with no warnings.

| Artifact | Path/Link | Short description |
|---------|------|---------|
| Self-Signed Cockpit Certificate | `docs/artifacts/traefik/cockpit-self-signed.tls` | Self-Signed Internal Cockpit Certificate - Redacted |
| Wildcard Cockpit Certificate | `docs/artifacts/traefik/cockpit-wildcard-traefik.tls` | Wildcard Traefik Cockpit Certificate - Redacted |
| Self-Signed Web-Browser Certificate Information | `docs/artifacts/traefik/cockpit-self-signed.png` | Self-Signed Internal Cockpit Certificate - Redacted |
| Wildcard Web-Browser Certificate Information | `docs/artifacts/traefik/cockpit-wildcard-traefik.png` | Wildcard Traefik Cockpit Certificate - Redacted |

## 6. Rollback Plan

Rollback in this scenario would be triggered by a failure in name resolution or instability. A failure to update the certificates would not be a rollback trigger. A security exception would be required, which is already the current state. 

Steps:

1. Roll Back the original Docker Compose and `.env` files from before the traefik implementation (version controlled in public or private Git repository)
2. Re-write the cloudflare tunnel rules to go back to IP-based routing instead of internal DNS.

Estimated RTO: 20-25min.

## 7. Trade-offs, Risks and Mitigations

- **Trade-offs:** 
- **Risk:** Traefik crash brings down all internal services
  -  **Mitigation:** Backups are enforced, and out-of-bands management is maintained, ensuring a quick fix.
- **Risk:** Traefik Host crash while out-of-premise can result in out-of-band management systems being inaccessible.
  - **Mitigation:** Maintain Out-of-Bands Management tools accessible using IP-based communication, and keep the cloudflare tunnel resolution mapped thusly.

## 8. Security Impact (CIA)

- **Confidentiality:** All internal traffic is encrypted, which prevents rogue service snooping.
- **Integrity:** By not relying on exceptions, certificates can be trusted, and any tampering to the certificates will raise alerts instead of going unreported.
- **Availability:** Availability is slightly reduced. By introducing a single point of failure up the chain, service downtime is not only affected by the host itself, but also by the traefik container. This is accepted for the time being. High Availability solutions may be implemented in the future to mitigate this effect.

## 9. Implementation Notes

- Test with non-critical services first. `it-tools` is a good test-container that doesn't natively support encryption.
- For a self-signed service transision test-case `RHEL Cockpit` is a good candidate. While arguably critical, being a forwarded service, it will remain available on the {IP}:{PORT} regardless of proxy failure.

## 10. Post-implementation Review

**Date implemented:** 2026-08-05

**Outcome:** Pass
	- **AC-1:** All services are migrated and accessible within the trusted LAN. [2026-08-05]
	- **AC-2:** Services are, by default, inaccessible in other networks. Implemented by Traefik Template default middleware. [2026-08-05]
	- **AC-3:** Access Control Rules must allow for individual service authorization for devices and services cross-vlan, comparable to the current firewall + pinhole rule model. Implemented using Traefik Middleware configuration [2026-08-05]
	- **AC-4:** Docker Compose Files are version controlled. Implemented in both public and private GitHub repositories, depending on service. [2026-08-05]

**Follow-ups:**

- Owner: Marcos Tobon
- Date planned: [Recovery Plan Test - 2026-08-10]
- Final review date: [2026-08-14]

---

## Minimal ADR checklist
- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [ ] Rolled out and tested recovery plan [SCHEDULED - 2026-08-10]

---
## Index Registration
> **Index Entry:** | 009 | 2026-08-02 | [Traefik as Reverse Proxy with DNS-01 Wildcard Certificates](adrs/adr-2026-08-02-009-traefik-as-reverse-proxy-with-dns-01-wildcard-certificates.md) | Implemented |
