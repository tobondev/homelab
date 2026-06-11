# Architecture Decision Records Index

This log captures the significant architectural decisions for the homelab environment, tracking the transition from consumer-grade monolithic routing to an enterprise-grade, segmented x86 core.

| ID | Date | Decision | Status |
|:---|:---|:---|:---|
| 001 | 2026-03-24 | [Centralize L3 services on OPNsense (Lenovo M920q)](adrs/adr-2026-03-24-001-centralize-l3-opnsense.md) | Implemented |
| 002 | 2026-04-03 | [Adopt source-level patching and automated upstream monitoring](adrs/adr-2026-04-03-002-hybrid-patching-posture.md) | Implemented |
| 003 | 2026-04-05 | [Ansible-Driven OpenWRT Provisioning for batman-adv Mesh](adrs/adr-2026-04-05-003-ansible-driven-openwrt-provisioning-for-batman-adv-mesh.md) | Implemented |
| 005 | 2026-04-04 | [LGAP Stack for SIEM and IDS Integration](adrs/adr-2026-04-04-005-lgap-stack-for-siem-and-ids-integration.md) | In Progress |
| 004 | 2026-04-10 | [Implementing SOPS as the Production Secrets Management](adrs/adr-2026-04-10-005-implementing-sops-as-the-production-secrets-management.md) | Implemented |
| 001 | 2026-04-22 | [Intentional Deferral of Out-of-Band Python Patching](adrs/adr-2026-04-22-006-intentional-deferral-of-out-of-band-python-patching.md) | Implemented |
| 007 | 2026-06-06 | [Wazuh XDR as Security Monitoring Platform](adrs/adr-2026-06-05-007-wazuh-xdr-as-security-monitoring-platform.md) | Accepted |
| 008 | 2026-06-05 | [Deploy Wazuh XDR in Parallel with HIIP](adrs/adr-2026-06-06-008-deploy-wazuh-xdr-in-parallel-with-hiip.md) | Accepted |
