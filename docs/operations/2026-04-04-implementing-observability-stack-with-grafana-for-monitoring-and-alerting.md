# Sysadmin Log: Implementing Observability Stack with Grafana for Monitoring and Alerting

**Date:** 2026-04-04
**Report Time:** 14:37
**Category:** Architecture | Monitoring
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

* **Decision 2:~Extrernalized configuration via `.env` files ~~+`.gitignore`**~~ -- Partially Superseeded per ADR-004.
    * *Rationale:* Hardcoding ports and paths limits flexibility and increases risk of secrets leakage; by combining this with .gitignore, it provides a secure production baseline. ~~This is an interim solution, as the system transitions towards a dedicated secrets management tool (SOPS or equivalent)~~. SOPS is implemented as of 2026-04-17.

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

**Incident 1 — YAML syntax error:** `docker compose up` reported a formatting error in `docker-compose.yml`. File was edited to resolve the syntax issue and spin-up was reattempted.

**Incident 2 — Stale container name conflicts:** Grafana and Alloy containers failed to create due to name conflicts with stub containers from the previous attempt. Identified and removed stale containers:
```bash
docker container rm {CONTAINER_NAME}
```

Stack spun up cleanly on the subsequent attempt. Confirmed via:
```bash
docker compose logs -f
```
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
Alloy failed to read `/var/run/docker.sock` for container discovery. Resolving this error by running the container with root privilages was deemed unnacceptable as a solution.
*Resolution:* The `alloy` user was added to the docker group and `/var/run/docker.sock` was mounted as read-only; this required using the host PID to allow access to host-processes.
This is a temporary solution, since it bypasses process isolation; see below.

**Incident 4 — Security Risks of Bypassing Process Isolation:**
Alloy handles too many tasks and sensitive information, including logs for OPNsense and other applications; it also exposes it to a wider attack surface, since every log source is a potential attack vector. 
*Resolution:* Potential solutions include Direct Log File Scraping, a Docker Socket Proxy, or forgoing docker log collection.
Allowing it to run without process-isolation in production is unacceptable, a permanent solution is required.


**Incident 5 — Loki Ingestion Rate Limits & Backpressure:**
Alloy attempted to ingest the entire historical backlog of host Docker logs simultaneously, tripping Loki's default 7-day timestamp rejection and 4MB/s rate limit.
*Resolution:* Tuned `loki-config.yaml` to increase `reject_old_samples_max_age` to 720h (30 days), and increased `ingestion_rate_mb` to 50 and `per_stream_rate_limit` to 50MB.

**Incident 6 — Prometheus Remote Write Rejection:**
Prometheus actively refused metrics pushed from Alloy, returning HTTP 404 errors.
*Resolution:* Added the `--web.enable-remote-write-receiver` flag to the Prometheus container execution command to unlock push-based telemetry ingestion.


**Incident 7 — Alloy Configuration Validation Error:**
Alloy was showing warnings with incorrect syslog formatting coming from the opnsense_telemetry job;
*Resolution:* Identified Alloy's preference for RFC5424 syslog formatting. Enabled RFC5424 in the OPNsense Web-UI. Confirmed Alloy natively auto-detects RFC5424 formatting without explicit declaration and validated ingestion.

* **Phase 5 (OPNsense Telemetry Verification):**

Configured OPNsense to forward syslog data. Restructured the Alloy pipeline using `loki.process` to intercept the raw syslog stream and append static labels (`job="opnsense_telemetry"`, `instance="lenovo-m920q"`) before forwarding to Loki. 

Successfully verified active data streams in Grafana Explore for both Loki (Docker logs + OPNsense Syslog) and Prometheus (Host metrics + Docker cAdvisor metrics).

---

## 4. Outcome & Future Considerations (Updated 2026-04-17)

**Session 1 result:** Core observability stack deployed and running on the server. Grafana, Loki, and Prometheus are operational and interconnected. Alloy is configured and healthy. No data is yet flowing — ingestion configuration is pending.

**Session 2 result:** Telemetry pipelines are actively flowing. OPNsense base syslog, Docker container metrics, and host metrics are successfully ingesting. Stack hardening and permission boundaries have been enforced.

**Technical debt:**
~~- OPNsense syslog forwarding not yet configured~~ Resolved 2026-04-17
- Suricata EVE JSON ingestion not yet configured
- Wazuh manager not yet deployed (planned: server VM)
- Alerting rules and notification channels not yet defined
~~- Secrets management transition (SOPS) pending~~ Resolved 2026-04-14

Configuration for Alloy ingestion of OPNsense syslog and Suricata EVE JSON was found thanks to `TurboKre's Blog`.

```
loki.write "local_loki" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

loki.source.syslog "syslog_firewall" {
  listener {
    address = "0.0.0.0:8091"
    idle_timeout = "60s"
    label_structured_data = true
    labels = {
      job = "syslog",
      app = "filterlog",
    }
  }
  forward_to = [loki.process.firewall_ips.receiver]
}

loki.source.syslog "syslog_ids" {
  listener {
    address = "0.0.0.0:8092"
    idle_timeout = "60s"
    label_structured_data = true
    labels = {
      job = "syslog",
      app = "suricata",
    }
  }
  forward_to = [loki.process.ids_ips.receiver]
}

loki.process "firewall_ips" {
  forward_to = [loki.relabel.hostname_labels.receiver]

  stage.regex {
    expression = ",(?P<srcip>([0-9]+\\.[0-9\\.]+)|([0-9a-fA-F]*:[0-9a-fA-F:]+)),(?P<dstip>([0-9]+\\.[0-9\\.]+)|([0-9a-fA-F]*:[0-9a-fA-F:]+)),"
  }

  stage.geoip {
    source = "srcip"
    db = "/etc/alloy/GeoLite2-City.mmdb"
    db_type = "city"
  }

  stage.labels {
    values = {
      src_city_name = "geoip_city_name",
      src_country_name = "geoip_country_name",
      src_location_latitude = "geoip_location_latitude",
      src_location_longitude = "geoip_location_longitude",
    }
  }

  stage.geoip {
    source = "dstip"
    db = "/etc/alloy/GeoLite2-City.mmdb"
    db_type = "city"
  }

  stage.labels {
    values = {
      dst_city_name = "geoip_city_name",
      dst_country_name = "geoip_country_name",
      dst_location_latitude = "geoip_location_latitude",
      dst_location_longitude = "geoip_location_longitude",
    }
  }
}

loki.process "ids_ips" {
  forward_to = [loki.relabel.hostname_labels.receiver]

  stage.json {
    expressions = {
      srcip = "src_ip",
      dstip = "dest_ip",
    }
  }
  
  stage.geoip {
    source = "srcip"
    db = "/etc/alloy/GeoLite2-City.mmdb"
    db_type = "city"
  }

  stage.labels {
    values = {
      src_city_name = "geoip_city_name",
      src_country_name = "geoip_country_name",
      src_location_latitude = "geoip_location_latitude",
      src_location_longitude = "geoip_location_longitude",
    }
  }

  stage.geoip {
    source = "dstip"
    db = "/etc/alloy/GeoLite2-City.mmdb"
    db_type = "city"
  }

  stage.labels {
    values = {
      dst_city_name = "geoip_city_name",
      dst_country_name = "geoip_country_name",
      dst_location_latitude = "geoip_location_latitude",
      dst_location_longitude = "geoip_location_longitude",
    }
  }
}

loki.relabel "hostname_labels" {
  forward_to = [loki.write.local_loki.receiver]

  rule {
    action        = "replace"
    target_label  = "hostname"
    replacement   = "OPNSense.example.com"  # don't work, need investigation
  }
}

```

This configuration is being studied and modified to add to the local implementation.


### Next Steps
- [ ] **Pending:** Resolve container isolation issues with Alloy Docker log ingestion OR disable Docker integration.
- [x] **Completed:** Configure OPNsense syslog forwarding to Alloy receiver; verify log ingestion in Loki and Grafana. (2026-04-17)
- [ ] **Pending:** Configure Suricata on OPNsense and add EVE JSON ingestion pipeline in Alloy.
- [ ] **Pending:** Deploy Wazuh manager in server VM; connect existing Wazuh agent on OPNsense.
- [ ] **Pending:** Define Grafana alerting rules for high-priority Suricata signatures and failed auth events; configure webhook notification channel.
- [x] **Completed:** Transition `.env` secrets to SOPS-managed encrypted files. (2026-04-14)
