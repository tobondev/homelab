# Incident Report: Manual deployment of upstream BSD patches for CURL CVEs

**Date of Incident:** 2026-04-02
**Date of Report:** 2026-04-03
**Status:** Resolved
**Severity:** Medium
**Services Impacted:** OPNsense Core, Automated Update Services, Remote Backup Scripts (libssh), WAN-facing API clients.
**CVE ID(s):** CVE-2026-3805, CVE-2026-3783, CVE-2026-3784, CVE-2026-1965, CVE-2025-15224, CVE-2025-15079, CVE-2025-14819, CVE-2025-14524, CVE-2025-14017, CVE-2025-13034,
---

## 1. Executive Summary
After a routine system update, the built-in security audit tool for OPNsense firmware revealed the installed CURL version (8.17.0) was susceptible to multiple high-severity flaws. These included memory corruption (Use-after-free), credential leakage and authentication bypasses. Due to a lack of binary updates in the production repository, a manual upstreaming of the OPNsense Ports tree was required to reach a secure version (8.19.0) by building from source.

## 2. Timeline of Events

* **[11:40]** - Marcos triggered a routine system update. The system revealed no updates available.
* **[11:42]** - As a precaution, Marcos ran a security audit, to identify any gaps and vulnerabilities not addressed by the production repository
* **[11:43]** - The security audit revealed multiple curl CVE's
* **[11:45]** - Further investigation of the reports in the FreeBSD VuXML database revealed the CVEs impact
* **[11:46]** - Using said VuXML database, the minimum safe version was identified as curl v. 8.19.0
* **[11:46]** - Performing a package upgrade in OPNsense resulted in no curl upgrade. Upstreaming was chosen as a solution.
* **[11:58]** - Initial triage and investigation commenced.
* **[12:33]** - Triage revealed that, while serious, the vulnerabilities were not critical and did not require an immediate fix
* **[12:51]** - Upstreaming the affected packages from FreeBSD was chosen as the best solution
* **[13:31]** - After thorough investigation, a well documented approach for patch upstreaming was found
* **[15:21]** - This foundation was polished and expanded to account for dependencies, since it was outside the scope of the original code
* **[17:35]** - The script was deployed in an OPNsense VM, to test the effects of the tool; issues with parsing proved too time-consuming to fix

### NEXT DAY - 2026-04-03

* **[10:55]** - Research into other remediation strategies, pros and cons was conducted.
* **[11:10]** - The decision to pivot to backporting manually was made, by fetching the upstream binary from FreeBSD.
* **[11:35]** - A virtualized environment was used to develop and test a strategy.
* **[12:15]** - Dependency errors were encountered, revealing an incompatibility with the upstream FreeBSD curl package.
* **[12:20]** - The decision to use the opnsense ports tree to build from source was made.
* **[13:20]** - A virtualized environment was used to compile, install, and check stability and viability of backporting by compiling from source.
* **[13:30]** - A potential for unintended rollback by the OPNsense package manager identified; curl was manually locked from automatic updates.
* **[13:35]** - A potential for package drift was identified as a result of this solution. Development commenced on a script to remediate this.
* **[14:15]** - Script development finished.
* **[14:45]** - After thorough testing, the patch method was approved for production.
* **[15:00]** - A runbook for deployment of manual backported packages was written.
* **[15:11]** - Said runbook was used to guide the deployment of the patch in production.
* **[15:21]** - The patch deployment process provided guidance on small updates to the runbook, and additional details to the incident report.
* **[15:22]** - After said small updates, the runbook was deemed to be production ready.
* **[15:25]** - The patch deployment was successful.
* **[15:28]** - Vulnerability scanner was run again, and revealed all known vulnerabilities were patched. Versions were checked manually to confirm.
* **[15:30]** - As per runbook instructions, the upstream check script was deployed as a daily cron job.
* **[15:32]** - System was successfully patched and is fully operational and up to date.

## 3. Risk Assessment
#### Risk Assessment Matrix

| Likelihood \ Severity | Very Low | Low | Medium | High | Very High |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Very High** | Medium | High | High | **Critical** | **Critical** |
| **High** | Medium | Medium | High | High | **Critical** |
| **Medium** | Low | Medium | Medium | High | High |
| **Low** | Very Low | Low | Medium | Medium | High |
| **Very Low** | Very Low | Very Low | Low | Medium | Medium |



### Risk Assessment Analysis

|  CVE                 	|  Severity  	|  OPNsense Exposure                            	| Risk 	|  Fixed In  	|
|----------------------	|------------	|-----------------------------------------------	|------	|------------	|
|  :---                	|  :---      	|  :---                                         	|	|  :---      	|
|  **CVE-2025-14819**  	|  Medium    	|  **HIGH** — TLS cert bypass on handle reuse   	| Very High  |  8.18.0    	|
|  **CVE-2025-15224**  	|  Medium    	|  **HIGH** — same class                        	| Very High  |  8.18.0    	|
|  **CVE-2026-1965**   	|  Medium    	|  **MEDIUM** — Negotiate auth if GSSAPI built  	| Medium |  8.19.0    	|
|  **CVE-2026-3784**   	|  Medium    	|  Low-Medium — proxy credential isolation      	| Low  	|  8.19.0    	|
|  **CVE-2026-3783**   	|  Medium    	|  Low — OAuth2 token leak                      	| Low  	|  8.19.0    	|
|  **CVE-2025-14524**  	|  Medium    	|  Low — OAuth2 cross-protocol                  	| Low  	|  8.18.0    	|
|  **CVE-2026-3805**   	|  Medium    	|  Low — SMB UAF, not used                      	| Low  	|  8.19.0    	|
|  **CVE-2025-15079**  	|  Medium    	|  Low — libssh not default                     	| Low  	|  8.18.0    	|
|  **CVE-2025-14017**  	|  Medium    	|  Very Low — legacy LDAP backend                	| Very Low |  8.18.0    	|
|  **CVE-2025-13034**  	|  Medium    	|  Very Low — GnuTLS QUIC only                   	| Very Low |  8.18.0    	|



## 4. Root Cause Analysis (RCA)

The root cause of this incident was an inherent supply-chain delay between upstream vulnerability disclosures and vendor repository updates. OPNsense prioritizes firewall stability, which introduces a necessary testing lag between the time a third-party package (like curl) is patched upstream and when it is compiled, tested, and pushed to the OPNsense production repositories. Consequently, the system was left temporarily exposed to publicly disclosed CVEs. The lack of a native, automated mechanism to bridge this patch gap for critical packages required manual intervention via the OPNsense ports tree to secure the environment without breaking core OS dependencies.

## 5. Remediation and Recovery

* **Triage:** 
	- Prioritized the development and expansion of a script that can be reused for upstreaming bsd patches, and started development of a runbook
	- Found a well documented approach to upstream patches with a dynamic script (artifacts/freebsd-upstream-update-script.md)
	- Determined this could be expanded and improved to add support for dependency checks.

* **Execution:** 
	- During development of the script, several issues were found with parsing the yaml-wrapped JSON format of FreeBSD pkg repositories, and the decision was made to postpone the building of an automated tool for a future project, and focus on upstreaming curl manually
	- A backup of the repository configuration file was created for safekeeping
		``` cp /usr/local/etc/pkg/repos/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf.bak ```
	- Nano was used to insert a specific configuration for the upstream details
		``` nano /usr/local/etc/pkg/repos/FreeBSD-UPSTREAM.conf  ```
	- The following configuration was added, using expansion for  '${ABI}'  (Application Binary Interface) to ensure architecture and version compatibilty without hardcoding BSD versions:
		``` 
		FreeBSD-UPSTREAM: {
		  url: "pkg+https://pkg.FreeBSD.org/${ABI}/latest",
		  mirror_type: "srv",
		  signature_type: "fingerprints",
		  fingerprints: "/usr/share/keys/pkg",
		  enabled: yes
		}
		```
	- The package repository was updated using ` pkg update `

	- Then the custom repository was specifically called upon for the curl package upgrade

		``` pkg upgrade -r FreeBSD-UPSTREAM curl ```

	- The pkg utility demanded updating before performing curl upgrade; before continuing, research was done on the consequences.

	- Research revealed OPNsense customises the pkg utility, and it may not be fully compatible with the standard FreeBSD installation.

	- To avoid added risks of drift, the pkg version was locked using `pkg lock -y pkg` and the upgrade was attempted again.
	
	- Upon attempting upgrade again, pkg flagged libssh2 as a dependency.
```
		pkg: libssh2 is not installed, therefore upgrade is impossible
		The following 2 package(s) will be affected (of 0 checked):

		New packages to be INSTALLED:
		        libssh2: 1.11.1,3 [FreeBSD-UPSTREAM]

		Installed packages to be UPGRADED:
		        curl: 8.17.0 -> 8.19.0_1 [FreeBSD-UPSTREAM]

		Number of packages to be installed: 1
		Number of packages to be upgraded: 1
```
	- This message suggested that the curl implementation in OPNsense was built in a fundamentally different way, independent of the libssh2 package, unlike the upstream BSD version; this made the individual package backporting by using upstream binaries impossible, due to dependency incompatibilities.

	- Given the extreme consequences of breaking curl and the entire ssl library, the decision to build from source was made.
	
	- To give back control to the official OPNsense repository, the pkg package was unlocked using `pkg unlock -y pkg`

	- For extra precaution, the temporary upstream repository was renamed to avoid other packages being pulled, and the original was verified as unchanged
		``` mv /usr/local/etc/pkg/repos/FreeBSD-UPSTREAM.conf /usr/local/etc/pkg/repos/FreeBSD-UPSTREAM.conf.bak ```
		and
		``` diff /usr/local/etc/pkg/repos/FreeBSD.conf.bak /usr/local/etc/pkg/repos/FreeBSD.conf ```
	- The repository database was updated again to flush out upstream BSD packages
		``` pkg update ```

	- The local copy of the OPNsense ports tree was updated using `opnsense-code ports`
	
	- This triggered the installation of two dependencies:
```
		git: 2.53.0 [OPNsense]
	        p5-Error: 0.17030 [OPNsense]
```

	- The contents of the `curl` port directory were examined using `ls` and `cat`; port version was revealed to be 8.17;
	
	- The Makefile was updated from  `PORTVERSION=	8.17.0` to `PORTVERSION=	8.19.0`; the checksum was then updated using `make makesum`

	- The compiler successfuly fetched curl version 8.19.0 from the curl database
```
			===>   curl-8.19.0 depends on file: /usr/local/sbin/pkg - found
			=> curl-8.19.0.tar.xz doesn't seem to exist in /usr/ports/distfiles.
			=> Attempting to fetch https://curl.se/download/curl-8.19.0.tar.xz
			curl-8.19.0.tar.xz                                    2722 kB   31 MBps    00s
			===> Fetching all distfiles required by curl-8.19.0 for building
```

	- Configuration was run using `make config`; the existing OPNsense compilation flags were confirmed to have libssh/libssh2 unchecked, which matched expectations, given the absence of either package in the default OPNsense installation.

	- A new snapshot was created via the OPNsense GUI, in order to safeguard against potential breakages.

	- The old version of curl was uninstalled and the new version was installed using `make deinstall && make install clean`
	
	- Installation succeeded. The following message was displayed:
```
		===>   Registering installation for curl-8.19.0
		Installing curl-8.19.0...
		===> SECURITY REPORT: 
		      This port has installed the following files which may act as network
		      servers and may therefore pose a remote security risk to the system.
		/usr/local/lib/libcurl.so.4.8.0
		/usr/local/lib/libcurl.a(libcurl_la-tftp.o)

		      If there are vulnerabilities in these programs there may be a security
		      risk to the system. FreeBSD makes no guarantee about the security of
		      ports included in the Ports Collection. Please type 'make deinstall'
		      to deinstall the port if this is a concern.

		      For more information, and contact details about the security
		      status of this software, see the following webpage: 
			https://curl.se/
	
```
	- Executed `curl -V` to confirm version was successfully upgraded to 8.19.0
```
		curl 8.19.0 (amd64-portbld-freebsd14.3) libcurl/8.19.0 OpenSSL/3.0.19 zlib/1.3.1 brotli/1.2.0 zstd/1.5.7 libidn2/2.3.8 libpsl/0.21.5 nghttp2/1.68.0
		Release-Date: 2026-03-11
```
	- Ran security audit again to confirm vulnerability warnings were gone. Security audit confirmed patch success.

	- Upon reviewing GUI, a php error message was found;
```

		PHP Warning: PHP Startup: Unable to load dynamic library 'curl.so' (tried: /usr/local/lib/php/20230831/curl.so (Shared object "libcurl.so.4" not found, required by "curl.so"), /usr/local/lib/php/20230831/curl.so.so (Cannot open "/usr/local/lib/php/20230831/curl.so.so")) in Unknown on line 0 

```
	- This is likely due to the brief moment in time when curl was removed and then reinstalled, since the GUI is still up and running. However, additional testing was determined to be necessary in order to verify the hypothesis

	- The web gui was restarted by running  `/usr/local/etc/rc.restart_webgui`

	- The restart was clean, and caused no errors. Log files were checked without filtering, confirming that there are only Notice logs, logging the successful restart of the GUI. This confirmed that the error was the result of a temporary race condition, and resolved itself once the new curl version was installed.

	- Curl version was locked using `pkg lock -y curl`

	- Script was developed to ensure package unlock once the repository catches up. System location is `/usr/local/bin/opnsense-check_package_upstream_version.sh`. Script can be found at  `scripts/admin/opnsense-check_package_upstream_version.sh`

	- Script was manually tested by locking another package that is current (python3 was chosen) to verify alerting.

	- Alerting failed. Further testing indicated that this was a result of python3 being a meta-package. Test was repeated using 'pkg' as target and it succeeded.

	- Script was configured as cron job and scheduled to test automated trigger. System location is `/usr/local/opnsense/service/conf/actions.d/actions_custompatch.conf`. Configuration can be found at `artifacts/opnsense/actions_custompatch.conf`
	- Configd was updated via `service configd restart` and custom action appeared in webui, and was scheduled to run daily at midnight.
	
	- Custom cron job was run manually using `configctl custompatch checkupstream` . Alerts were checked in logs. Success was verified.

	- Deployment was approved for production OPNsense installation, and the aformentioned steps were repeated.

	- A runbook for manual patching was written (`docs/runbooks/runbook-2026-04-03-001.md`) and tested by using it as the step-by-step guide to deploy the patch in production

	- The production system was snapshotted before upgrading curl to ensure speedy recovery in case of errror.

	- Installed the custom patch check utility and scheduled as cron job in production system.
	
* **Verification:** 
	- Executed `curl -V` to confirm version was successfully upgraded to 8.19.0
	- Ran security audit using pkg audit -F to confirm vulnerability warnings were gone. Security audit confirmed patch success.
	- The runbook was proven to be a highly functional, clear and detailed guide that enabled quick patching with no issues.

## 6. Lessons Learned & Action Items

- A simple script that keeps track of manually updated and version locked packages, and regularly checks them against the OPNsense repository.
- Said script was tested, deployed and scheduled as a cron job.
- Additionally, the vulnerability check process will ensure alerting occurs if new vulnerabilities are found in any packages, even if something fails and the package is not unlocked in a timely manner, providing a default security net.

- [x] **Completed:** Test and verify manual curl upgrade in VM
- [x] **Completed:** Write a script that dynamically queries the pkg repository for version parity against locked packages.
- [x] **Completed:** Schedule a cron job to check the OPNsense repository for version parity against locked packages and alert the administrator.
- [x] **Completed:** Test script manually in VM.
- [x] **Completed:** Test script as cron job in VM.
- [x] **Completed:** Deploy curl upgrade in production system
- [x] **Completed:** Deploy cron job for alerting script in production system
- [x] **Completed:** Write ADR documenting the logic behind the script as the preferred tool for patch upstreaming
- [x] **Completed:** Write runbook for patch upstreaming
