# Sysadmin Log: Infisical Deployment for Secrets Management

**Date:** 2026-11-12

**Report Time:** 08:46

**Category:** Security / Architecture

**Status:** In Progress

---

## 1. Context & Problem Statement

**One-line summary:** Deploy Infisical as the centralized secrets manager to issue machine-identity tokens, dynamically inject credentials into Docker deployments, and permanently deprecate file-backed `.sops.env` encryption.

**Background:** The infrastructure currently relies on a localized stop-gap that encrypts `.env` files into `.sops.env` files committed directly to the repository. While functional, this model breaks down in an automated GitOps workflow, requiring the CI/CD runner to hold a master decryption key. The infrastructure requires a centralized vault that issues short-lived, scoped machine identity tokens to the pipeline at runtime, ensuring no credentials are ever committed to the repository.

## 2. Architectural Decisions & Strategy

### Decision 1: Secret Scoping and Referencing

**Decision:** Utilize Infisical Environments to define server/host scopes, root folders for global variables (like `DOMAIN`), and sub-folders for project-specific secrets utilizing Secret Referencing (e.g., `${DOMAIN}`).

**Rationale:** This establishes a DRY (Don't Repeat Yourself) architecture. By defining `DOMAIN` globally within an environment and referencing it in project sub-folders, migrating a container to a different server or environment dynamically updates all dependent URLs and variables without requiring manual secret duplication or modification.

### Decision 2: Host-Level Agent Injection

**Decision:** Install the `infisical-agent` natively on host machines to intercept and inject secrets directly into the `docker compose` execution layer.

**Rationale:** Rather than modifying every single `docker-compose.yml` to use an Infisical Docker container wrapper, the native host agent acts as a transparent middleware. It fetches the secrets via a Machine Identity Token and pipes them directly to the Docker daemon at runtime.

## 3. Implementation & Execution

### Phase 1: Stack Deployment

The Infisical application stack was deployed using Docker Compose, consisting of the Node.js backend, a PostgreSQL 14 Alpine database, and a Redis caching layer. The Traefik configuration was applied to route `infisical.${DOMAIN}` strictly over HTTPS using Let's Encrypt.

### Phase 2: Host Agent Installation

The official Infisical CLI/Agent was installed on the Docker host using the Arch User Repository (AUR).

```bash
yay -S infisical-bin
```

### Phase 3: MVP Secret Creation and Validation

A pilot project ("IT-Tools") was established in the Infisical web interface. The global variable `DOMAIN` was created within the `Development` environment.

To validate the CLI injection capability, a manual deployment was successfully executed using the `infisical run` wrapper, which fetched the `DOMAIN` secret from the vault and injected it seamlessly into the Docker Compose process.

```bash
infisical run -- docker compose up -d

```

### Phase 4: GitOps Test

In order to test the Gitea + Infisical + Arcane Integration, a new test repository (`gitops-test`) is created. Then the remote is set and pushed to.


```bash
mkdir ../gitops-test
cd ../gitops-test
git init
git config --local user.email "marcos@tobon.dev"
git config --local user.name "Marcos Tobon"
mkdir -p docker/tools/it-tools
nano docker/tools/it-tools/docker-compose.yml
git add .
git commit -m "IT-Tools Compose Deploy"
git remote add origin ssh://git@gitea.${DOMAIN}:2222/tobondev/gitops-test.git
```

This test needs to be performed on an external machine, since the production Arcane Container is bind-mounted to the /opt/docker folder. The `curious-aristocrat-suse-server` machine is chosen for this purpose.


The repository structure:

```bash
├── .gitignore
└── docker
    ├── networking
    │   └── traefik
    │       ├── .env
    │       ├── config
    │       │   └── traefik.yml
    │       ├── docker-compose.yml
    │       └── dynamic_conf
    │           ├── authentik.yml
    │           ├── cockpit.yml
    │           ├── homeassistant.yml
    │           ├── meshcommander.yml
    │           ├── middlewares.yml
    │           ├── nanokvm.yml
    │           └── opnsense.yml
    ├── observability
    │   └── arcane
    │       ├── .env
    │       └── docker-compose.yml
```

Traefik and Arcane are deployed as usual, with .env files. No need for SOPS encryption for this test. The .env files are ignored using .gitignore. Once they are deployed and functional, Arcane will be configured for GitOps. Then Gitea will be connected with the runner to grab Infisical Secrets. Then the IT-Tools container will be added, commited and pushed to test the deployment hooks.

```bash
└── docker
    └── tools
        └── it-tools
            └── docker-compose.yml
```

```bash
sudo mkdir -p /srv/arcane/secrets
sudo install -m 600 -o root -g root /dev/null /srv/arcane/secrets/infisical.env
sudo nano /srv/arcane/secrets/infisical.env
```

```toml
INFISICAL_CLIENT_ID=${CLIENT_ID}
INFISICAL_CLIENT_SECRET=${CLIENT_SECRET}
DOMAIN=${DOMAIN}
```

```bash
sudo semanage fcontext -a -t container_file_t "/srv/arcane/secrets(/.*)?"
sudo restorecon -Rv /srv/arcane/secrets
ls -ldZ /srv/arcane/secrets
docker run --rm --entrypoint sh infisical/cli:<tag> -c 'infisical --version; id'
sudo docker run --rm --env-file /srv/arcane/secrets/infisical.env \
--entrypoint sh infisical/cli:latest -c \
'infisical login --method=universal-auth \
--client-id="$INFISICAL_CLIENT_ID" \
--client-secret="$INFISICAL_CLIENT_SECRET" \
--domain="$DOMAIN" \
--silent --plain'
```

Token Response OK.


```bash
sudo docker run --rm --env-file /srv/arcane/secrets/infisical.env \
  --entrypoint sh infisical/cli:latest -c '
    TOKEN=$(infisical login --method=universal-auth \
      --client-id="$INFISICAL_CLIENT_ID" \
      --client-secret="$INFISICAL_CLIENT_SECRET" \
      --domain="$DOMAIN" \
      --silent --plain)
    infisical export --token="$TOKEN" \
      --domain="$DOMAIN" \
      --projectId=<project-id> \
      --env=<environment-slug> \
      --format=dotenv'

```

Initially, this failed on access premissions. Adding the machine identity to the project fixed the issue, and then the right secret was returned. Which returned the right secret.

## 4. Outcome & Architectural Pivot

* **Result:** The centralized secrets vault was successfully brought online and routed through the Traefik proxy.
* **Result:** The Docker host successfully authenticated to the vault and proved capable of dynamic secret injection at the CLI level.

### Deployment Rejected

While the technical implementation was successful, evaluating the end-to-end GitOps flow revealed that Infisical introduces unacceptable fragility and complexity for a Docker Compose environment while offering no aditional security.

1. **The Stateful Dependency Trap:** Replacing a stateless encrypted file (`.sops.env`) required deploying a Node.js backend, a Postgres database, and a Redis cache. Pipeline deployments became strictly dependent on the uptime of a stateful database.

2. **The Security Illusion:** To bootstrap the Infisical CLI in Arcane, a plaintext `infisical.env` file containing the `CLIENT_ID` and `CLIENT_SECRET` had to be stored on the host. If the runner is compromised, this machine identity is exposed—providing no tangible security benefit over providing the runner with a SOPS master decryption key.

3. **Deployment Friction:** Injecting the secrets into Arcane's lifecycle hooks felt brittle, essentially requiring complex scripting to bridge the gap between the vault and the Docker daemon.

**Conclusion:** Infisical solves an enterprise scaling problem but introduces massive operational overhead for a single-admin homelab. The problem of "secrets in Git" can be solved natively, statelessly, and with far less friction by returning to SOPS.

## 5. Next Steps

* [x] **Completed:** Update `adr-2026-11-12-013-infisical-as-secrets-management-solution.md` status to **Rejected**, citing architectural complexity and stateful dependencies. [2026-11-12]
 
* [x] **Completed:** Update `ADR-004` to formally select SOPS with an Arcane pre-deploy decryption hook as the standard secrets management solution. [2026-11-12]

* [x] **Completed:** Spin down and purge the Infisical test stack and database. [2026-11-12]

* [x] **Completed:** Write a universal Arcane pre-deploy hook that decrypts `.sops.env` files using a securely mounted, read-only `age.key` on the runner host. [2026-11-12]
