# ADR 005: PLG Stack with Alloy for SIEM and IDS Integration

File: adr-2026-04-04-005-plg-stack-with-alloy-for-siem-and-ids-integration.md
Title: PLG Stack with Alloy for SIEM and IDS Integration
Date: 2026-04-04
Status: Proposed
Decider(s): @tobondev
Owner: @tobondev
Confidence: [High | Medium | Low]
Review-by: [YYYY-MM-DD - e.g., 6 or 12 months from Date]

---

## 1. Context and Problem Statement

**One-line summary:** Deploy a localized PLG (Prometheus, Loki, Grafana) observability stack utilizing Grafana Alloy as the unified telemetry collector to ingest and visualize Suricata and Wazuh security data from the OPNsense appliance.

**Background:** With Layer 3 routing and security centralized on the OPNsense appliance (Lenovo M920q), the network is now capable of generating rich IDS/IPS (Suricata) and endpoint/SIEM (Wazuh) telemetry. However, the existing infrastructure lacks a centralized, persistent, and secure mechanism to ingest, query, and alert on this data. A solution is required that provides robust SIEM capabilities without overwhelming the primary server's compute resources, while ensuring configurations and persistent state are strictly decoupled.

## 2. Considered Options
 
| Option ID | Short name | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|
| A | ELK Stack (Elasticsearch, Logstash, Kibana) | High | Low | High | 3-4 weeks |
| B | Cloud SIEM (e.g., Datadog, Splunk) | High | High | Low | 1-2 weeks |
| C | PLG Stack + Grafana Alloy | High | Low | Medium | 1-2 weeks |

## 3. Decision Outcome

**Chosen option:** Option C — PLG Stack + Grafana Alloy.
**Decision statement:** Implement Prometheus, Loki, and Grafana utilizing host-level bind mounts for state persistence, and deploy Grafana Alloy as the unified telemetry agent to collect, filter, and forward Suricata logs and Wazuh metrics from the OPNsense node.
**Rationale:**
 * **Pros:** Grafana Alloy replaces multiple disjointed agents (Promtail, Telegraf) with a single, highly configurable pipeline. The PLG stack is significantly more resource-efficient than a JVM-heavy ELK stack, leaving headroom on the Dell Precision host for future lab environments. Explicit bind mounts and environment variables ensure zero secret leakage in the repository.
* **Cons:** Loki's query language (LogQL) requires a learning curve compared to standard Lucene or SQL queries.
* **Neutral:** Requires manual host-level UID/GID permission management for the local `./data` directories prior to deployment.

## 4. Acceptance Criteria (measurable)

- **AC-1:** Suricata threat logs from OPNsense are successfully ingested via Alloy and queryable in Grafana via Loki.
- **AC-2:** Wazuh agent telemetry is successfully forwarded to the stack without dropped packets or pipeline backpressure.
- **AC-3:** `docker-compose up -d` successfully deploys using only relative bind mounts and `.env` variables, with no hardcoded credentials in version control.
- **AC-4:** Container destruction and recreation (`docker compose down -v` followed by `up`) results in zero loss of historical metric or log data.

## 5. Test Plan & Artifacts (links + short summary)

| Artifact | Path/Link | Short description |
|---------|------|---------|
| Observability Compose File | `docker-compose.yml` | Declarative infrastructure with explicit bind mounts and `.env` variable mapping. |
| Alloy Pipeline Config | `alloy/config.alloy` | Telemetry pipeline configuring syslog/API receivers for OPNsense data. |
| Host Permission Script | `scripts/set-permissions.sh` | Bash script setting `chown` for 10001 (Loki), 65534 (Prometheus), 472 (Grafana), and 473 (Alloy). |

## 6. Rollback Plan

1. Bring down the new observability stack (`docker compose down`).
2. Restore the previous `docker-compose.yml.bak` configuration.
3. Re-initialize legacy Docker named volumes from the most recent backup archive if necessary.
4. Disable the syslog/telemetry forwarding rules on the OPNsense appliance to prevent dropping unsent packets.

**Estimated RTO:** 10–15 minutes.

## 7. Trade-offs, Risks and Mitigations

- **Trade-offs:** Managing our own SIEM infrastructure increases operational overhead compared to a managed cloud solution, but guarantees complete data sovereignty and eliminates recurring subscription costs.
- **Risk:** Alloy pipeline misconfiguration drops critical security events. → **Mitigation:** Implement Alloy's local UI debugging mode during the staging phase and validate log ingestion against a known test payload before finalizing the pipeline.
- **Risk:** Uncapped log ingestion fills the host storage drive. → **Mitigation:** Enforce strict retention policies in `loki-config.yml` and `prometheus.yml` (e.g., `--storage.tsdb.retention.size=2GB`), utilize BTRFS quotas on the host subvolumes, and rely on btrbk to handle snapshotting and remote backups, with a data-retention policy that allows for fast, local access for recent logs and long-term storage for older ones.

## 8. Security Impact (CIA)

- **Confidentiality:** Infrastructure as Code (IaC) is entirely sanitized of secrets via `.env` files, allowing safe publishing to public repositories.
- **Integrity:** Utilizing explicit host bind mounts prevents data corruption issues sometimes associated with Docker's internal volume management during daemon crashes.
- **Availability:** The lightweight nature of the PLG stack ensures the monitoring tooling does not cause resource starvation on the host machine, maintaining high availability for the security monitoring plane. Additionally, using docker compose allows for both clean restarts in case of system failure, and paves the way for a HA setup that can be easily replicated and deployed, or load-balanced in failover mode.

---
## Index Registration
> **Index Entry:** | 002 | 2026-04-04 | [PLG Stack with Alloy for SIEM and IDS Integration](adrs/adr-2026-04-04-005-plg-stack-with-alloy-for-siem-and-ids-integration.md) | Proposed |
