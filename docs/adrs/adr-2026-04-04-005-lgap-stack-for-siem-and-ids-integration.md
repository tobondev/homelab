# ADR 005: LGAP Stack for SIEM and IDS Integration

File: adr-2026-04-04-005-lgap-stack-for-siem-and-ids-integration.md
Title: LGAP Stack for SIEM and IDS Integration
Date: 2026-04-04
Status: In Progress
Decider(s): @tobondev
Owner: @tobondev
Confidence: High 
Review-by: 2026-06-11

---

## 1. Context and Problem Statement

**One-line summary:** Deploy a localized LGAP (Loki, Grafana, Alloy, Prometheus) observability stack utilizing Grafana Alloy as the unified telemetry agent to collect, filter and forward Suricata and Wazuh security data from the OPNsense appliance.

**Background:** With Layer 3 routing and security centralized on the OPNsense appliance (Lenovo M920q), the network is now capable of generating rich IDS/IPS (Suricata) and endpoint/SIEM (Wazuh) telemetry. However, the existing infrastructure lacks a centralized, persistent, and secure mechanism to ingest, query, and alert on this data. A solution is required that provides robust SIEM capabilities without overwhelming the primary server's compute resources, while ensuring configurations and persistent state are strictly decoupled.

## 2. Considered Options
 
| Option ID | Short name | Description | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|------------|
| A | ELK Stack (Elasticsearch, Logstash, Kibana) | Industry-standard but resource-intensive JVM-based logging stack. | High | Low | High | 3-4 weeks |
| B | Cloud SIEM (e.g., Datadog, Splunk) | Hosted, managed observability with low operational overhead but high recurring subscription costs. | High | High | Low | 1-2 weeks |
| C | LGAP Stack (Loki, Grafana, Alloy, Prometheus) | Lightweight, localized observability stack using Alloy as a unified telemetry agent. | High | Low | Medium | 1-2 weeks |

## 3. Decision Outcome

**Chosen option:** Option C — LGAP Stack  (Loki, Grafana, Alloy, Prometheus)
**Decision statement:** Implement Loki, Grafana and Prometheus, with Alloy as the unified telemetry agent to collect, filter and forward Suricata logs and Wazuh metrics from the OPNsense node. Utilize host-level bind-mounts paired with `docker-compose` and SOPS-encrypted `.env` variables separation, for state persistence and secure, version-controlled infrastructure suitable for public repository publication.
**Rationale:**
 * **Pros:** Grafana Alloy replaces multiple disjointed agents (Promtail, Telegraf) with a single, highly configurable pipeline. The LGAP stack is significantly more resource-efficient than a JVM-heavy ELK stack, leaving headroom on the Dell Precision host for future lab environments. Explicit bind mounts and environment variables ensure zero secret leakage in the repository.
* **Cons:** Loki's query language (LogQL) requires a learning curve compared to standard Lucene or SQL queries.
* **Neutral:** Requires manual host-level UID/GID permission management for the local `./data` directories prior to deployment.

## 4. Acceptance Criteria (measurable)

- **AC-1:** Suricata threat logs from OPNsense are successfully ingested via Alloy and queryable in Grafana via Loki. *(MET: 2026-04-23)*
- **AC-2:** Wazuh agent telemetry is successfully forwarded to the stack without dropped packets or pipeline backpressure. *(Pending Wazuh Implementation)*
- **AC-3:** `docker-compose up -d` successfully deploys using only relative bind mounts and `.env` variables, with no hardcoded credentials in version control. *(MET: 2026-04-17)*
- **AC-4:** Container destruction and recreation (`docker compose down -v` followed by `up`) results in zero loss of historical metric or log data. *(MET: 2026-04-23 - Loki persistence directory mismatch resolved)*
- **AC-5:** Alloy collects host-metrics and docker logs while maintaining process isolation and without requiring root privileges. Confirmed by `docker-compose.yml` (permissions) and `config.alloy` (collection) configuration.
- **AC-6:** Suricata and OPNsense rules are tuned to prevent false positives, reducing signal to noise ratio.
- **AC-7:** Alerting pipeline is defined and tested. Verification criteria pending on Alerting platform decision.
- **AC-8:** Alerting rules are defined for high-priority Suricata and OPNsense events. Verified by Alloy Alerting ruleset.


## 5. Test Plan & Artifacts (links + short summary)

**Test plan (high level):**
1. Deploy LGAP compose stack in staging; verify container health and volume persistence.
2. Map OPNsense syslog output to Alloy receiver port; verify RFC5424 parsing.
3. Enable Suricata ruleset in OPNsense; trigger test alerts and verify EVE JSON ingestion.
4. Inject MaxMind GeoLite2 database; verify geographic label enrichment in Grafana Explore.
5. Test alerting plane by artificially severing OPNsense telemetry to trigger dead-man's switch.

| Artifact | Path/Link | Short description |
|---------|------|---------|
| Observability Compose File | `docker/observability/grafanaloki/docker-compose.yml` | Declarative infrastructure with explicit bind mounts and `.env` variable mapping. |
| Encrypted .env file | `docker/observability/grafanaloki/sops.env` | SOPS-encrypted variables for `docker-compose.yml`. |
| Alloy Pipeline Config | `docker/observability/grafanaloki/alloy/config.alloy` | Telemetry pipeline configuring syslog/API receivers for OPNsense data. |

## 6. Rollback Plan

1. Bring down the new observability stack (`docker compose down`).
2. Disable the syslog/telemetry forwarding rules on the OPNsense appliance to prevent dropping unsent packets.

**Estimated RTO:** 5 minutes.

## 7. Trade-offs, Risks and Mitigations

- **Trade-offs:** Managing our own SIEM infrastructure increases operational overhead compared to a managed cloud solution, but guarantees complete data sovereignty and eliminates recurring subscription costs.
- **Risk:** Alloy pipeline misconfiguration drops critical security events. → **Mitigation:** Implement Alloy's local UI debugging mode during the staging phase and validate log ingestion against a known test payload before finalizing the pipeline.
- **Risk:** Uncapped log ingestion fills the host storage drive. → **Mitigation:** Enforce strict retention policies in `loki-config.yml` and `prometheus.yml` (e.g., `--storage.tsdb.retention.size=2GB`), utilize BTRFS quotas on the host subvolumes, and rely on btrbk to handle snapshotting and remote backups, with a data-retention policy that allows for fast, local access for recent logs and long-term storage for older ones.
- **Risk:** Alloy requires Docker socket access to discover container metrics, but mounting `/var/run/docker.sock` directly into the container bypasses process isolation and creates a severe attack surface. → **Mitigation:** Implemented `tecnativa/docker-socket-proxy` as an internal, read-only API gateway on the Docker network. Alloy queries the proxy via TCP, explicitly blocking all `POST/DELETE` requests and enforcing least-privilege access.

## 8. Security Impact (CIA)

- **Confidentiality:** Infrastructure as Code (IaC) is entirely sanitized of secrets via SOPS-encrypted `.env` files, allowing safe publishing to public repositories.
- **Integrity:** Utilizing explicit host bind mounts prevents data corruption issues sometimes associated with Docker's internal volume management during daemon crashes.
- **Availability:** The lightweight nature of the LGAP stack ensures the monitoring tooling does not cause resource starvation on the host machine, maintaining high availability for the security monitoring plane. Additionally, using docker compose allows for both clean restarts in case of system failure, and paves the way for orchestrated deployment for a rapid Disaster Recovery solution.

## 9. Implementation Notes (sanitized)

- Create a minimum viable Suricata Ruleset by using the Emerging Threats ruleset.
- Use OPNsense as a test-subject for alerting. Create an alert for log downtime and test.

## 10. Post-implementation Review
**Date implemented:** 2026-04-23 | Partial
**Outcome:** Partially Implemented
	- **AC-1:** OPNsense log forwarding configured. (2026-04-23)
	- **AC-2:** [ PENDING ] [(yyyy-mm-dd)]
	- **AC-3:** Implemented SOPS-encrypted environment variables (2026-04-23)
	- **AC-4:** Confirmed stack data persistence (2026-04-23)
	- **AC-5:** Implemented `docker-socket-proxy` to resolve Alloy permission creep. (2026-04-23)
	- **AC-6:** [ PENDING ] [(yyyy-mm-dd)]
	- **AC-7:** [ PENDING ] [(yyyy-mm-dd)]
	- **AC-8:** [ PENDING ] [(yyyy-mm-dd)]
**Follow-ups:**

- Tune Suricata Ruleset (AC-6):
	- Owner: Marcos Tobon
	- Date planned: (2026-04-29)
- Deploy Wazuh and configure Wazuh Agent Log Forwarding (AC-2):
	- Owner: Marcos Tobon
	- Date planned: (2026-05-25)
- Define Notification Channels (AC-7):
	- Owner: Marcos Tobon
	- Date planned: (2026-05-03)
- Triage Alerting Notification Priority (AC-8):
	- Owner: Marcos Tobon
	- Date planned: (2026-05-13)

- Final review date:
	- Scheduled for 2026-05-30

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
> **Index Entry:** | 005 | 2026-04-04 | [LGAP Stack for SIEM and IDS Integration](adrs/adr-2026-04-04-005-lgap-stack-for-siem-and-ids-integration.md) | In Progress |
