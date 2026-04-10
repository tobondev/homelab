# Sysadmin Log: Implementing Observability Stack with Grafana for Monitoring and Alerting

**Date:** 2026-04-04
**Report Time:** 14:37
**Category:** Architecture | Maintenance
**Status:** In Progress

---

## 1. Context & Problem Statement

The homelab is currently undergoing a strategic shift to build out a comprehensive observability and security monitoring posture, incorporating centralized log ingestion, IDS/IPS telemetry (Suricata) and host-based intrusion detection (Wazuh). The recently deployed OPNsense appliance  (see: `docs/adrs/adr-2026-03-24-001-centralize-l3-opnsense.md`) provides the network foundation for this capability


Before configuring data sources, the goal of this session was to validate that the core observability stack, consisting of Grafana, Loki, Prometheus and Alloy, could be deployed in a clean, maintanable and secret-safe configuration, while maintaining portfolio visibility. A previous incomplete attempt at this stack existed and was used as a baseline.

Planned data sources (pending future sessions):
- OPNsense syslog -> Alloy syslog receiver
- Suricata EVE JSON -> Alloy file-based ingestion
- Wazuh manager alerts -> Loki pipeline
- Host metrics -> Prometheus / Alloy
- Workstation metris -> Prometheus / Alloy
- OpenWRT mesh metrics -> Prometheus / Alloy

## 2. Architectural Decisions & Strategy

* **Decision 1: Host bind mounts instead of Docker named volumes**
    * *Rationale:* Mapping presistent data to local subdirectories (I.E. ./docker/stacks/observability/grafana/data) alongside their respective configuration files provides transparent control over their state, and allows for more flexibility of backups using existing tools such as btrbk or rsync.

* **Decision 2: Extrernalized configuration via `.env` files +`.gitignore`**
    * *Rationale:* Hardcoding ports and paths limits flexibility and increases risk of secrets leakage; by combining this with .gitignore, it provides a secure production baseline. This is an interim solution, as the system transitions towards a dedicated secrets management tool (SOPS or equivalent).

* **Decision 3: MVP-first stack spin-up before introducing data sources**

- *Rationale:* Verifying the core stack (Grafana UI reachable, Prometheus and Loki connected as data sources, Alloy pipeline healthy) before configuring OPNsense syslog forwarding or Suricata reduces the number of simultaneous failure points during initial deployment.

## 3. Implementation & Execution

### Session 1 -- 2026-04-04

* **Phase 1 (Preparation):**

Synced the previous incomplete PLG stack progress into the repository structure, preserving permissions using `rsync -a` paired with `sudo` to maintain container ownership of the volumes, which ensures they can run with the least privilege.

```
❯ sudo rsync -a oldattempt/workinprogress/grafanaloki ./docker/observability
```
Immediately following the synchronization, the `.gitignore` file was updated to include the `.env` files in the docker-compose stack and `git status` was run to verify that the `.env` file wasn't being tracked for changes. Updated `docker-compose.yml` to ensure all sensitive values were mapped to variables in the `.env` instead of being hardcoded.

Transferred the full stack directory to server. Sudo was missed from the rsync command, resulting in ownership being dropped.

```
❯ rsync -aP -e "ssh -p 54792" ./docker/observability/grafanaloki {USER}@{SERVERIP}:/{DOCKER}/{STORAGE/{LOCATION}/
```
SSH was used to remotely access the server, where `ls -Rl` confirmed permissions had not been preserved. Corrected using `chown -R {USER}:{GROUP}`  on all {SERVICE}/data folders. 

Once this was resolved, `docker compose up -d` was used to attempt to spin up the stack. 

**Incident 1 — YAML syntax error:** `docker compose up` 
reported a formatting error in `docker-compose.yml`. File was 
edited to resolve the syntax issue and spin-up was reattempted.

**Incident 2 — Stale container name conflicts:** Grafana and 
Alloy containers failed to create due to name conflicts with 
stub containers from the previous attempt. Identified and 
removed stale containers:
```bash
docker container rm {CONTAINER_NAME}
```

Stack spun up cleanly on the subsequent attempt. Confirmed 
via:
```bash
docker compose logs -f
```
Accessed Grafana Web UI, changed administrator password 
(stored in encrypted vault). Connected Prometheus and Loki as 
data sources using internal Docker network addressing 
(`http://{service_name}:{internal_port}`) rather than 
host-mapped ports, enabled by all services sharing the same 
compose network.

Populated `config.alloy` with pipeline configuration covering:
- OPNsense syslog receiver (mapped to unprivileged port, 
  pending OPNsense-side configuration)
- Basic host metrics
- Docker container metrics
- Internal Alloy pipeline health
- Loki push target

Restarted Alloy container to validate configuration syntax. 
Restart succeeded with no errors.

**Phase 3 (Verification):**

Stack confirmed running with all containers healthy. Grafana 
UI reachable. Prometheus and Loki data sources connected. 
Alloy configuration loaded without syntax errors.

OPNsense syslog ingestion is **not yet verified** — the 
syslog receiver port is configured in Alloy but OPNsense has 
not been pointed at it. This is intentional per the MVP-first 
decision; ingestion verification is the first objective of the 
next session.

Transferred updated `docker-compose.yml`, `.env` (excluded 
from git), and `config.alloy` back to the repository via 
`rsync` for version control. Closed SSH session.

---

## 4. Outcome & Future Considerations

**Session 1 result:** Core observability stack deployed and 
running on the server. Grafana, Loki, and Prometheus are 
operational and interconnected. Alloy is configured and 
healthy. No data is yet flowing — ingestion configuration 
is pending.

**Technical debt:**
- OPNsense syslog forwarding not yet configured
- Suricata EVE JSON ingestion not yet configured
- Wazuh manager not yet deployed (planned: server VM)
- Alerting rules and notification channels not yet defined
- Secrets management transition (SOPS) pending

### Next Steps
- [ ] **Pending:** Configure OPNsense syslog forwarding to 
  Alloy receiver; verify log ingestion in Loki and Grafana.
- [ ] **Pending:** Configure Suricata on OPNsense and add 
  EVE JSON ingestion pipeline in Alloy.
- [ ] **Pending:** Deploy Wazuh manager in server VM; connect 
  existing Wazuh agent on OPNsense.
- [ ] **Pending:** Define Grafana alerting rules for 
  high-priority Suricata signatures and failed auth events; 
  configure webhook notification channel.
- [ ] **Pending:** Transition `.env` secrets to SOPS-managed 
  encrypted files.
