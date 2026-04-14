# Sysadmin Log: Deploying a Secrets Management Implementation with SOPS  [Brief, Clear Title - e.g., Decoupling Docker State and IaC]

**Date:** 2026-04-10
**Report Time:** 16:56
**Category:** Architecture | Security
**Status:** Implemented

---

## 1. Context and Problem Statement

**One-line summary:** Adopt Mozilla SOPS with AGE encryption to manage and version infrastructure secrets within the public Git repository.

**Background:**

The current workflow maintains two parallel files for each secrets-containing configuration: a live `.env` file with real credentials, excluded from version control via `.gitignore`, and a manually maintained sanitized counterpart containing dummy values that is safe to commit publicly. As configurations evolve, both files must be kept in sync manually — a burden that has already deferred publication of the Docker infrastructure configurations entirely, and will only compound as the Ansible provisioning project (ADR-003) grows. Automated pipelines cannot safely reference the sanitized files without substitution logic, undermining the GitOps model the repository is built around.

This decision was also triggered directly by ADR-003: Section 7 of that document identifies a residual risk — the shared Ansible management key — whose resolution path explicitly depends on a secrets management architecture being in place.

## 2. Architectural Decisions & Strategy

**Decision statement:** Implement Mozilla SOPS with AGE encryption to manage repository secrets, utilizing local key storage protected by host-level Full Disk Encryption (FDE) and backed up securely via Bitwarden and encrypted AWS pipelines.

**Rationale:**

The primary objective is to maintain a public-facing GitOps repository that proves infrastructure logic without leaking sensitive credentials. Option A is the easiest but strips valuable context and breaks automated provisioning. Option B is enterprise-grade but introduces unacceptable stateful overhead for a homelab environment.

The decision ultimately comes down to Option C vs. Option D. SOPS is selected because its encryption is explicit rather than transparent. When SOPS encrypts a YAML or JSON file, it encrypts only the values, leaving the keys readable in plaintext. This allows public viewers to understand the configuration structure — network interface names, VLAN assignments, playbook parameters — without seeing the sensitive payloads. Option C carries the critical flaw of failing silently on misconfiguration; SOPS guarantees that unencrypted data will not be accidentally staged, as the file itself is visibly transformed.

Finally, pairing SOPS with AGE rather than PGP (deprecated) or Cloud KMS eliminates reliance on an external cloud provider's API. AGE is a simple, modern, and stateless cryptographic tool that keeps the security boundary entirely local.

## 3. Implementation & Execution

* **Phase 1: Installing SOPS and AGE:**

╰─ yay -S sops❯ yay -S sops
:: Proceed with installation? [Y/n] y
╰─ yay -S age
:: Proceed with installation? [Y/n] y
╰─ age-keygen -ohkey.txt
Public key: age1cnl02cmv4w3pe570pxyc0dm0p3zz26h8fehamlarf8ppupwwhgsqq6shaw
╰─ mkdir ~/.sops

* **Phase 2: Minimum Viable Implementation:**

╰─ echo "export SOPS_AGE_KEY_FILE="export SOPS_AGE_KEY_FILE=~/.sops/key.txt" >> ~/.zshrc❯
╰─ nano .sops.yaml
╰─ cat .sops.yaml❯ cat .sops.yaml
creation_rules:
  - path_regex: \.y?ml$
    age: "age1cnl02cmv4w3pe570pxyc0dm0p3zz26h8fehamlarf8ppupwwhgsqq6shaw"
╰─ nano mvp-secret.yml
╰─ sops -e -i mvp-secret.yml
╰─ cat mvp-secret.yml❯ cat mvp-secret.yml
wifi_ssid: ENC[AES256_GCM,data:Ioturdy9DQORkSiuu2NSLdGpBzMw,iv:Dzgt+B81d3+T0j5EzTV9Qq4KEJFjYI8jDYIeCpNnxlo=,tag:Jsat+LCWTlPPu6dByv010g==,type:str]
admin_password: ENC[AES256_GCM,data:TwwKPg/BRbt2VooWmZ4fFbG1yvWNY5oPqv4KDmu2ZUV6klu/FiweAj3w,iv:q8TAK5NON/1DW3MUfOQI9jQwOVEfDUgd+5bYqoLueco=,tag:stobU3N64IDr4H20qfD3dw==,type:str]
api_token: ENC[AES256_GCM,data:q/9vYlYHK/HNZQusARHPg/iMtOuyfs0Qmfpbr8J7iGfy6p2b5bI8Q+GDZs8=,iv:Q2gLvtr8vce1ujvfrMOui2apK5QSoatNSRfmAMIg414=,tag:9qr4J+wqkd5DhfadKp19GQ==,type:str]
sops:
    age:
	- recipient: age1cnl02cmv4w3pe570pxyc0dm0p3zz26h8fehamlarf8ppupwwhgsqq6shaw
	  enc: |
	    -----BEGIN AGE ENCRYPTED FILE-----
	    YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBIQ01OdmtaM3ZoZHgwREJm
	    OUJIcFdUdm1VUTV1aUVvM09OaXlLSXh1VGtvCnNYdjN6eGxBRWN1QmVkZEgzYWtU
	    OHFzNWs2eUQvM2V5ODU2VU5Tbld4Rk0KLS0tIEc0b2tLR0UwdVNEMWlKNHlONXFJ
	    aEJVTVZaZkgxd3BHeFY5emFDTWZKcUEK5VIB8LoIu+cKnQZ8tNfDAvnAHsEVaFvG
	    J7ZTzsoV+aIFl4lw3eRU2AfaETFPq4daZYDUGlwMJSRzGx1fB1W8Hw==
	    -----END AGE ENCRYPTED FILE-----
    lastmodified: "2026-04-10T21:05:41Z"
    mac: ENC[AES256_GCM,data:feMiiMH+7PUt+4CzNsQFGQdy+eavro0UPf+xyxV+j2BZyDWGaCHweDn7Bjo/LQVkS26IIKnCQG4TWc8/P6iVAsJKRy2hZAQzM1z7ucRkGRjdM9etnC7VVZoMn/EezaeCw0Yj+OLCOePcuDlgfexOLGxTyQIVvBr9cBu1di+jU+c=,iv:u83nq2FIR4EpTnHosmQjhmDvPb5Xz4ahq/DpWsn8mj0=,tag:9nZuKK5qO9O+M1oMCHuDPQ==,type:str]
    unencrypted_suffix: _unencrypted
    version: 3.12.2
╰─ source ~/❯zsource ~/.zshrc
* **Phase 3: Verification:**

╰─ sops mvp-secret.yml
╰─ cat
LICENSE		  README.md	    docker/	      docs/		host-configs/	  mvp-secret.yml    portfolio-index/  scripts/	      cat
mvp-secret.yml
wifi_ssid: ENC[AES256_GCM,data:Ioturdy9DQORkSiuu2NSLdGpBzMw,iv:Dzgt+B81d3+T0j5EzTV9Qq4KEJFjYI8jDYIeCpNnxlo=,tag:Jsat+LCWTlPPu6dByv010g==,type:str]
admin_password: ENC[AES256_GCM,data:pOUwX3/0CTBzKd94wsbPlzg9dJKv1So2dsv5Z2x0FkBaq2ZXOr4dBOddYVotBoGI3MV3PH8tLu+6P12Xrek=,iv:p4Z3jDio+iKT/GkcrEMyoTbbhtbYvugVrnasPCFik6o=,tag:5W/WhN/tVckn409OIOV09A==,type:str]
api_token: ENC[AES256_GCM,data:q/9vYlYHK/HNZQusARHPg/iMtOuyfs0Qmfpbr8J7iGfy6p2b5bI8Q+GDZs8=,iv:Q2gLvtr8vce1ujvfrMOui2apK5QSoatNSRfmAMIg414=,tag:9qr4J+wqkd5DhfadKp19GQ==,type:str]
sops:
    age:
	- recipient: age1cnl02cmv4w3pe570pxyc0dm0p3zz26h8fehamlarf8ppupwwhgsqq6shaw
	  enc: |
	    -----BEGIN AGE ENCRYPTED FILE-----
	    YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBIQ01OdmtaM3ZoZHgwREJm
	    OUJIcFdUdm1VUTV1aUVvM09OaXlLSXh1VGtvCnNYdjN6eGxBRWN1QmVkZEgzYWtU
	    OHFzNWs2eUQvM2V5ODU2VU5Tbld4Rk0KLS0tIEc0b2tLR0UwdVNEMWlKNHlONXFJ
	    aEJVTVZaZkgxd3BHeFY5emFDTWZKcUEK5VIB8LoIu+cKnQZ8tNfDAvnAHsEVaFvG
	    J7ZTzsoV+aIFl4lw3eRU2AfaETFPq4daZYDUGlwMJSRzGx1fB1W8Hw==
	    -----END AGE ENCRYPTED FILE-----
    lastmodified: "2026-04-10T21:07:11Z"
    mac: ENC[AES256_GCM,data:zJpN41dALqalZd0eFpRa2tSXSZPnh/3/7IDviPzD5x5uF+WPP6djRf0YClXCJK9r9oRL+uqx+Mu4FN496Gu4rp96OFTXr9Tz6/TMGrvN4QxIsgYKIpvrQn5qs6pv5yBufVCG3zfw7QmItxXzKnNvsZc7nW/PmYLJkFlkwes3zzE=,iv:Y5P4++E5d5RQ+5DrIFCqUfPUqmSt9C3ZYn5a/LXrJqo=,tag:QRp7NUPErXfL+DCDK8b8sg==,type:str]
    unencrypted_suffix: _unencrypted
    version: 3.12.2
╰─ sops -d mvp-secret.yml
wifi_ssid: this-is-a-dummy-value
admin_password: please-dont-use-this-as-your-password-ever-i-changed-it-anyway
api_token: s8k98fkaudsa89fk89rncdeDS_F*Y(KTHDiksathdkiu


## 4. Outcome & Future Considerations

* **MVP Test successful:**
  Minimum Viable Product verified via `mvp-secret.yml`. Encryption, decryption, and structural
  key preservation all confirmed. _(2026-04-10)_

* **Production MVP test successful:**
  SOPS applied to `openwrt-secrets.yml` and `hosts.yml`. Both files committed to `sops-deployment`
  branch with all sensitive values encrypted and structural keys readable in plaintext. _(2026-04-10)_

* **Key Backup Verified:**
  AGE key vaulted in Bitwarden. Recovery verified by `sha256sum` comparison against working key
  and successful `sops -d` decryption of a live secrets file.
  See `docs/artifacts/SOPS/age-key-backup-verification.md`. _(2026-04-10)_

* **Confirmed containment of secrets:**
  `git diff-index` executed against `main`. All created or modified files confirmed as either
  SOPS-encrypted or structurally safe. Zero plaintext leakage. _(2026-04-10)_

* **Phase 4: Ansible Integration (2026-04-14):**
  `community.sops.load_vars` integrated into all four production playbooks. Full hardening
  sequence executed against all five active nodes with SOPS-decrypted secrets consumed at
  runtime. No plaintext present in the playbook directory during execution. `host_vars` for
  all five nodes migrated to SOPS-encrypted `.sops.yml` files via the Day-0 bootstrap path
  in `ansible-security-hardening.yml`. AC-2 satisfied.

### Next Steps

- [x] **Completed:** Deploy minimum viable product of SOPS as secrets management. _(2026-04-10)_
- [x] **Completed:** Implement Ansible-SOPS integration (`community.sops.load_vars`). _(2026-04-14)_
- [x] **Completed:** Test integration — successful execution across all five active nodes. _(2026-04-14)_
- [x] **Completed:** Execute `git diff main` pre-merge gate, log artifact. _(2026-04-10)_
- [ ] **Pending:** Implement Jinja2 template for LuCI lockdown artifact to automate IP redaction.
  Low priority — manual redaction functional.
