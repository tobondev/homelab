# Sysadmin Log: Implementing Observability Stack with Grafana for Monitoring and Alerting

**Date:** 2026-04-04
**Report Time:** 14:37
**Category:** Architecture | Monitoring
**Status:** In Progress

---

## 1. Context & Problem Statement

The homelab is currently undergoing a strategic shift to build out a comprehensive observability and security monitoring posture, incorporating centralized log ingestion, IDS/IPS telemetry (Suricata) and host-based intrusion detection (Wazuh). The recently deployed OPNsense appliance (see: `docs/adrs/adr-2026-03-24-001-centralize-l3-opnsense.md`) provides the network foundation for this capability.


Before configuring data sources, the goal of this session was to validate that the core observability stack, consisting of Grafana, Loki, Prometheus and Alloy, could be deployed in a clean, maintainable and secret-safe configuration, while maintaining portfolio visibility. A previous incomplete attempt at this stack existed and was used as a baseline.

Planned data sources:
- OPNsense syslog -> Alloy syslog receiver. (2026-04-17)
- Suricata EVE JSON -> Alloy file-based ingestion. (2026-04-23)
- Wazuh manager alerts -> Loki pipeline [Pending]
- Host metrics -> Prometheus / Alloy. (2026-04-23)
- Workstation metrics -> Prometheus / Alloy [Pending]
- OpenWRT mesh metrics -> Prometheus / Alloy [Pending]

## 2. Architectural Decisions & Strategy

### Decision 1: Host bind-mounts for Docker stack

**Decision:** Use host bind-mounts over docker named volumes for persistent data storage.

**Rationale:** Mapping persistent data to local subdirectories (e.g. ./docker/stacks/observability/grafana/data) alongside their respective configuration files provides transparent control over their state, and allows for more flexibility of backups using existing tools such as btrbk or rsync.

### Decision 2: Separate Secrets from compose architecture

**Decision:**  Externalized configuration via `.env` files and `SOPS` -- Updated to follow ADR-004. (2026-04-17)

**Rationale:** Hardcoding ports and paths limits flexibility and increases risk of secrets leakage; using SOPS provides a way to encrypt sensitive configuration details while still displaying the logic behind the design for portfolio visibility.

### Decision 3: Prioritize MVP stack spin-up

**Decision:** Develop and spin-up LGAP stack before introducing Suricata and OPNsense as data sources

**Rationale:** Verifying the core stack (Grafana UI reachable, Prometheus and Loki connected as data sources, Alloy pipeline healthy) before configuring OPNsense syslog forwarding or Suricata reduces the number of simultaneous failure points during initial deployment.

## 3. Implementation & Execution

### Session 1 -- 2026-04-04

* **Phase 1 (Preparation):**

Synced the previous incomplete PLG stack progress into the repository structure, preserving permissions using `rsync -a` paired with `sudo` to maintain container ownership of the volumes, which ensures they can run with the least privilege.

```
❯ sudo rsync -a oldattempt/workinprogress/grafanaloki ./docker/observability
```
Immediately following the synchronization, the `.gitignore` file was updated to include the `.env` files in the docker-compose stack and `git status` was run to verify that the `.env` file wasn't being tracked for changes. Updated `docker-compose.yml` to ensure all sensitive values were mapped to variables in the `.env` instead of being hardcoded.

Transferred the full stack directory to server. However, `sudo` was missed from this rsync command, resulting in ownership being dropped.

```
❯ rsync -aP -e "ssh -p 54792" ./docker/observability/grafanaloki {USER}@{SERVERIP}:/{DOCKER}/{STORAGE}/{LOCATION}/
```
SSH was used to remotely access the server, where `ls -Rl` confirmed permissions had not been preserved. Corrected using `chown -R {USER}:{GROUP}` on all {SERVICE}/data folders. 

Once this was resolved, `docker compose up -d` was used to attempt to spin up the stack. 

**Incident 1 — YAML syntax error:** `docker compose up` reported a formatting error in `docker-compose.yml`. File was edited to resolve the syntax issue and spin-up was reattempted.

**Incident 2 — Stale container name conflicts:** Grafana and Alloy containers failed to create due to name conflicts with stub containers from the previous attempt. Identified and removed stale containers:
```bash
docker container rm {CONTAINER_NAME}
```

Stack spun up cleanly on the subsequent attempt. Confirmed via:
```bash
docker compose logs -f
```
* **Phase 2 (Configuration):**

Accessed Grafana Web UI, changed administrator password (stored in encrypted vault). Connected Prometheus and Loki as data sources using internal Docker network addressing (`http://{service_name}:{internal_port}`) rather than host-mapped ports, enabled by all services sharing the same compose network.

Populated `config.alloy` with pipeline configuration covering:
- OPNsense syslog receiver (mapped to unprivileged port, pending OPNsense-side configuration)
- Basic host metrics
- Docker container metrics, with naming discovery
- Internal Alloy pipeline health
- Loki push target

Restarted Alloy container to validate configuration syntax. 

**Phase 3 (Verification):**

Stack confirmed running with all containers healthy. Grafana UI reachable. Prometheus and Loki data sources connected. Alloy is reporting syntax warnings for the data ingestion configuration, but is healthy otherwise. Postponing review until the following session was deemed acceptable.

OPNsense syslog ingestion is **not yet verified** — the syslog receiver port is configured in Alloy but OPNsense has not been pointed at it. This is intentional per the MVP-first decision; ingestion verification is the first objective of the next session.

Transferred updated `docker-compose.yml`, `.env`, and `config.alloy` back to the repository via `rsync` for version control. Closed SSH session.


### Session 2 -- 2026-04-17

* **Phase 4 (Ingestion & Pipeline Hardening):**

Resumed stack configuration to address failing telemetry ingestion. Identified and resolved several core pipeline bottlenecks:

**Incident 3 — Alloy Least-Privilege Execution:**
Alloy failed to read `/var/run/docker.sock` for container discovery. Resolving this error by running the container with root privileges was deemed unacceptable as a solution.
*Resolution:* The `alloy` user was added to the docker group and `/var/run/docker.sock` was mounted as read-only; this required using the host PID to allow access to host-processes.
This is a temporary solution, since it bypasses process isolation; see below.

**Incident 4 — Security Risks of Bypassing Process Isolation:**
Alloy handles too many tasks and sensitive information, including logs for OPNsense and other applications; this exposes the system to a wider attack surface, since every log source is a potential attack vector. 
*Resolution:* Potential solutions include Direct Log File Scraping, a Docker Socket Proxy, or forgoing docker log collection.
Allowing Alloy to run without process-isolation in production is unacceptable; a permanent solution is required.


**Incident 5 — Loki Ingestion Rate Limits & Backpressure:**
Alloy attempted to ingest the entire historical backlog of host Docker logs simultaneously, tripping Loki's default 7-day timestamp rejection and 4MB/s rate limit.
*Resolution:* Tuned `loki-config.yaml` to increase `reject_old_samples_max_age` to 720h (30 days), and increased `ingestion_rate_mb` to 50 and `per_stream_rate_limit` to 50MB.

**Incident 6 — Prometheus Remote Write Rejection:**
Prometheus actively refused metrics pushed from Alloy, returning HTTP 404 errors.
*Resolution:* Added the `--web.enable-remote-write-receiver` flag to the Prometheus container execution command to unlock push-based telemetry ingestion.


**Incident 7 — Alloy Configuration Validation Error:**
Alloy was showing warnings with incorrect syslog formatting coming from the opnsense_telemetry job.
*Resolution:* Identified Alloy's preference for RFC5424 syslog formatting. Enabled RFC5424 in the OPNsense Web-UI. Confirmed Alloy natively auto-detects RFC5424 formatting without explicit declaration and validated ingestion.

* **Phase 5 (OPNsense Telemetry Verification):**

Configured OPNsense to forward syslog data. Restructured the Alloy pipeline using `loki.process` to intercept the raw syslog stream and append static labels (`job="opnsense_telemetry"`, `instance="lenovo-m920q"`) before forwarding to Loki. 

Successfully verified active data streams in Grafana Explore for both Loki (Docker logs + OPNsense Syslog) and Prometheus (Host metrics + Docker cAdvisor metrics).

### Session 3 -- 2026-04-23

* **Phase 6 (Loki Data Persistence):**

**Incident 8 — Loki misconfiguration preventing data permanence**
Exploring the Loki data folder revealed it to be empty despite previously verified data ingestion. The cause was identified as `loki-config.yml` setting `path_prefix: /etc/loki`, causing the container to write chunks and index data inside its configuration directory, instead of the `/loki` bind mount defined in `docker-compose.yml`. 
*Resolution:* Modified `loki-config.yml` file to point to `/loki`, aligning it with compose expectations. Data directory now populated as expected. AC-4 re-confirmed.

* **Phase 7 (Enforce Docker Socket Isolation):**

In order to allow observability for Docker, without granting  Alloy root privileges or direct socket access, `dockerproxy` was added to the stack. This container holds the direct socket mount and exposes a constrained read-only TCP API. This reduces the blast radius of an attack by separating duties. The additional resource consumption of a fifth container in the stack was deemed an acceptable trade-off. `config.alloy` was modified to point to the TCP address of Docker Proxy instead of the Unix socket directly.

* **Phase 8 (Enforce minimal privileges for host metric ingestion):**

Research into Systemd's default security model revealed that the `adm` group is given access to `/var/log`, including the systemd journal. Since Alloy no longer requires root access to read Docker logs, the next step was minimizing privileges required for host metrics collection. The compose file was modified to add Alloy to the `adm` group. This, combined with a read-only mount, is accepted as the minimum permission required. No root access is granted.

* **Phase 9 (Enabling Suricata as MVP for Log Ingestion):**

Configuration for Alloy ingestion of OPNsense syslog and Suricata EVE JSON was found thanks to [TurboKre's Blog](https://blog.kre3.net/en/article/opnsense-firewall-observation-with-grafana/).
This configuration was studied and modified to generate an implementation for our use-case.

**Incident 9 — Suricata alerts not triggering**
To create an initial framework for IDS/IPS monitoring and alerting, Suricata was enabled in OPNsense, using the Emerging Threats Open Ruleset. These were confirmed enabled and alerting. The pipeline was already built in Alloy, so a test was performed using `curl http://testmyids.org/uid/index.html`. No alerting. Configuration was re-checked, rules were found to have failed downloading. Rules were downloaded again and test was re-performed. No alerting. IDS was restarted. Test re-performed. No alerting.
*Resolution:* Set VLAN interfaces to promiscuous mode, which allowed the IDS to analyze traffic.

After Suricata Log generation was confirmed in OPNsense, Alloy was restarted and the logs started flowing into the previously configured Suricata Ingestion Port. Detections included DNS over HTTPS and P2P protocols; these are expected functions of the setup and need to be tuned out, but they serve to prove the system is analyzing traffic and logging alerts. AC-1 is satisfied 2026-04-23.

* **Phase 10 (GeoIP Enrichment):**

A MaxMind developer account was created and the GeoLite2-City database was obtained. The database file was encrypted with `SOPS` and `gitignored` to prevent unauthorized redistribution. `docker-compose.yml` and `.env` were updated to add a read-only bind mount for the database file at `/etc/alloy/GeoLite2-City.mmdb`. The GeoIP enrichment stages in `config.alloy` were uncommented; the Alloy container was restarted. After a short warm-up period, `src_city_name`, `src_country_name`, `src_location_latitude`, and `src_location_longitude` labels began populating on Suricata events in Grafana Explore, confirming the integration.

* **Phase 11 (Alerting MVP):**

A test of Grafana alerting capabilities was designed by using the absence of OPNsense telemetry as an alert trigger. This was chosen due to the simplicity of implementation and absence of noise. A Grafana alert rule was created to monitor for OPNsense logs every minute, with a 5-minute wait before firing. Remote logging was disabled in OPNsense at 13:25. At 13:30 the alert status changed to Pending. At 13:31 the status switched to Firing. Logging was re-enabled in OPNsense at 13:32. Within 2 minutes, the status was back to normal. This verifies the MVP for the Alerting Pipeline.

**Note:** A notification contact point (webhook or email) has not yet been configured. The alert fires and resolves correctly within the Grafana UI; external alert delivery remains pending.

---

## 4. Outcome & Future Considerations (Updated 2026-04-23)

**Session 1 result:** Core observability stack deployed and running on the server. Grafana, Loki, and Prometheus are operational and interconnected. Alloy is configured and healthy. No data is yet flowing — ingestion configuration is pending.

**Session 2 result:** Telemetry pipelines are actively flowing. OPNsense base syslog, Docker container metrics, and host metrics are successfully ingesting. Stack hardening and permission boundaries have been enforced.

**Session 3 result:** Full security observability pipeline is operational. OPNsense base syslog, Docker container metrics and host metrics are ingesting successfully. Alloy permissions sprawl has been resolved by using `docker-socket-proxy` and host permissions have been removed. Suricata IDS events are enriched with GeoIP thanks to MaxMind database integration. Grafana alerting MVP tested and verified. Stack framework is deemed production stable at its current scope. Future work will focus on data visualization, parsing, dashboards and alerting.

**Technical debt:**
- Wazuh manager not yet deployed. [Planned: server VM]
- Alerting rules and notification channels not yet defined. [In Progress]
- Visualization Dashboard needs design and implementation. [In Progress]
- Log normalization needs to isolate baseline noise. [Data collection In Progress]


### Next Steps

- [x] **Completed:** Fix Loki data persistence (`path_prefix` misconfiguration).  _(AC-4, 2026-04-23)_
- [x] **Completed:** Resolve container isolation issues with Alloy Docker log ingestion via `docker-socket-proxy`. _(AC-5, 2026-04-23)_
- [x] **Completed:** Configure OPNsense syslog forwarding to Alloy receiver; verify log ingestion in Loki and Grafana. _(AC-1, 2026-04-23)_
- [x] **Completed:** Configure Suricata on OPNsense, add EVE JSON ingestion pipeline in Alloy. _(AC-1, 2026-04-23)_
- [x] **Completed:** Download and mount GeoLite2-City database, verify MaxMind GeoIP enrichment and implement. _(2026-04-23)_
- [x] **Completed:** Define MVP Grafana alerting rules (Dead-Man's Switch for OPNsense telemetry loss). _(2026-04-23)_
- [ ] **Pending:** Tune Suricata ruleset to baseline network traffic and reduce false-positive noise. _(AC-6, pending)_
- [ ] **Pending:** Define notification channels (Webhook/Discord) for Grafana alerts. _(AC-7, pending)_
- [ ] **Pending:** Define Grafana alerting rules for high-priority Suricata signatures and failed auth events. _(AC-8, pending)_
- [ ] **Pending:** Deploy Wazuh manager in server VM; connect existing Wazuh agent on OPNsense. _(AC-2, pending)_
- [x] **Completed:** Transition `.env` secrets to SOPS-managed encrypted files. _(AC-3, 2026-04-14 -- ADR-004, 2026-04-23)_
