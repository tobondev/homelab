# Sysadmin Log: Gitea Deployment

**Date:** 2026-11-11

**Report Time:** 18:47

**Category:** Architecture

**Status:** In Progress

---

## 1. Context & Problem Statement


### One-line summary

Migrate the primary Git remote to a self-hosted Gitea instance to act as a private CI/CD control plane, while utilizing push-mirroring to maintain GitHub as a sanitized, read-only public portfolio.

### Background

As the homelab infrastructure has grown, a need for a GitOps workflow has surfaced. The current workflow involves local commits, manual deployment of projects and .env files using `rsync` and `ssh`, resulting in configuration drifts. While a recent custom pre-commit hook (`sops-update.py`) solved the problem of accidentally forgetting to create or commit updated `.sops.env` files, this stop-gap solution highlights the lack of an automated CI/CD pipeline and a centralized execution environment capable of safely fetching credentials and deploying containers. The infrastructure now requires a strict separation of concerns: a private control plane for execution, automated secrets injection, and iteration, alongside a public display window for finalized states.

## 2. Architectural Decisions & Strategy


### Decision Statement

Deploy Gitea as the primary, self-hosted version control system and CI/CD engine. Configure Gitea to execute automated deployment pipelines internally, and set up a restricted Push Mirror to automatically synchronize the `main` branch to GitHub for portfolio presentation.

### Rationale

Gitea perfectly bridges the gap between resource efficiency and operational capability. It resolves the public/private repository conflict by allowing the entire development lifecycle (feature branches, WIP commits, failed pipeline runs) to remain strictly local. By relying on squash-merges into `main`, the public GitHub repository receives only clean, semantic commits representing successful infrastructure states via Gitea's native push-mirroring. GitLab was rejected purely on hardware inefficiency, and GitHub was rejected due to its lack of local execution and single-repo visibility controls.


## 3. Implementation & Execution

### Phase 1: Stack Deployment and Traefik Integration

Following the Gitea docker installation guide, Docker Compose was used to create the initial stack. Traefik definitions were split into two: an HTTP router for the UI, and a TCP router for the SSH service (port 2222). Most of the configurations, barring OIDC, were defined as environment variables, saved securely in the corresponding .env file. OIDC was configured in the interface directly due to the fact that the Environment configuration corresponds to an older OIDC implementation than that configured from the UI.

```toml
[server]
ROOT_URL=gitea.${DOMAIN}
SSH_DOMAIN=gitea.${DOMAIN}
SSH_PORT=2222
SSH_LISTEN_PORT=2222
DISABLE_SSH=false
PUBLIC_URL_DETECTION=auto
```

### Phase 2: OIDC Mapping

The scopes selected were `openid`, `email` and `profile`. This combination proved sufficient to satisfy the following criteria:

1. The user can directly login without manually providing an email (`email` scope)
2. The user can be given administrator privileges based on group membership (`profile` scope)

For the Administrator group, a `GiteaAdmins` group was created and the operator user was added.

![Gitea Admin Account Validation](../artifacts/gitea/2026-11-11_Gitea-OIDC-Admin-Mapping.png)

### Phase 3: Disallow Local Sign-in

The following (sanitized) configurations were set:

```toml
[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = false
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL = false
ENABLE_CAPTCHA = false
DEFAULT_KEEP_EMAIL_PRIVATE = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true
NO_REPLY_ADDRESS = noreply.localhost
ENABLE_BASIC_AUTHENTICATION = false
ENABLE_PASSWORD_SIGNIN_FORM = false

[oauth2_client]
USERNAME = nickname
ENABLE_AUTO_REGISTRATION = true
ACCOUNT_LINKING = login
```

This ensured that no local users could sign-in, while allowing autoregistration for OIDC users. With this Model, Authentik is in charge of Authorizing which users are allowed to create a log-in token for Gitea, meaning only authorized users can create an account, which is deemed an acceptable balance between security and usability.

![Gitea No Local Login](../artifacts/gitea/2026-11-11_Gitea-OIDC-Disallow-Local-Login.png)

### Phase 4: Mailer Configuration


```toml
[mailer]
PROTOCOL = SMTP
ENABLED = true
FROM = no-reply@${domain}
SMTP_PORT = ${SMTP_PORT}
USER = no-reply@${domain}
SMTP_ADDR = ${SMTP_ADDR}
EMAIL = ${EMAIL}
PASSWD = ${PASSWD}
```

### Phase 5: Local Repository Test

A new repository called `gitea-deployment-test` was created in the Gitea instance; after this, a new folder `gitea-deployment-test` was created in the parent folder of the `homelab` repository, git was initialized and an initial test commit was made.

```bash
mkdir ../gitea-deployment-test
cd ../gitea-deployment-test
git init
git config --local user.email "marcos@tobon.dev"
git config --local user.name "Marcos Tobon"
cat << EOF > README.md
# THIS IS A TEST
EOF
git add README.md
git commit -m "Initial Commit"
git remote add origin ssh://git@gitea.${DOMAIN}:2222/tobondev/gitea-deployment-test.git
```

Following this, an ssh key was added to the Gitea user and a push was attempted. After an initial failure and some debugging, the error turned out to be an unexpected default setting: `SSH_SERVER_USE_PROXY_PROTOCOL` defaults to true, which allows it to register the correct IP address when pushing a commit. However, Traefik requires specific configuration in its `serversTransport` to use the `v2` Proxy Protocol that Gitea expects. This was fixed by adding a `serversTransport` definition to the `middlewares.yml` file tcp section and updating the Gitea compose file to match.

Once this was done, the push succeeded.

![Gitea Local Push Success](../artifacts/gitea/2026-11-11_Gitea-SSH_Successful-Push.png)

### Phase 6: GitHub Mirror Test

In order to test the Upstream Mirroring, a private `gitea-deployment-test` repository was created in GitHub. To access it, a Personal Access Token dedicated to write requests to said repository was created, such that Gitea can always push code to it.

![Gitea GitHub Token MVP](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Mirroring-Token.png)

Using this token, Gitea push mirroring was configured, using the GitHub repository as upstream.

![Gitea Repo Mirror Config](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Mirroring-Sync-Config.png)

The "Synchronize Now" button was used to perform the first upstream mirror.

![Gitea Repo Mirror Push](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Mirroring-Push.png)

![Gitea Repo Mirror Push Success](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Mirroring-Push-Success.png)

With the mirroring validated, the only remaining step is to validate that pushing to the remote triggers a mirror.

```toml

cat << EOF > README.md
# THIS IS A SUCCESSFUL TEST
EOF
git add README.md
git commit -m "Second Commit"
git push
```

![Gitea Repo Mirror Second Push](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Mirroring-Second-Push.png)

Following this, the GitHub mirror was validated

![Gitea Repo Mirror Second Push Success](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Mirroring-Second-Push-Success.png)

### Phase 7: Homelab Repository Migration

Following this success, Gitlab is now approved to mirror to the upstream repository.

```bash
git remove remove origin
git remote add origin ssh://git@gitea.${DOMAIN}:2222/tobondev/homelab.git
# Push main - no upstream mirror config yet
git push -u origin main
# Push deploy/gitea -- feature branch with no upstream mirror by design
git push -u origin deploy/gitea
```

![Gitea Repo Mirror Local Deployment](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Mirroring-Deployment.png)

With this basic configuration, now the Token and mirror process is repeated for the `main` branch of the homelab repository.

The only remaining step in order to centralize management to the local Gitea instance is syncing the exsting GitHub issues to Gitea, making it the Local Source of Truth.


Because of how Gitea works, the only real way of doing this is by deleting the repository and re-adding it with the Migration tool. This, however, only has to be done once. At this point in time, the gitea-deployment-test repository was also deleted both from Gitea and GitHub, since it is no longer necessary.

![GitHub Repository Migration](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Migration-Start.png)

![GitHub Repository Migration](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Migration-Config.png)

![GitHub Repository Migration](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Migration-Deployment.png)

![GitHub Repository Migration](../artifacts/gitea/2026-11-11_Gitea_GitHub-Repo-Migration-Success.png)

At this point, the push validation was performed, which revealed Gitea's community edition only supports Push mirroring at a repository level, which would push the development branches to the GitHub remote. Since this is part of the problem that Gitea is trying to solve, push mirroring is then disabled and replaced with a Gitea action that pushes selectively.

In order to do so the `GITEA__actions__ENABLED` variable needs to be set to `true`, which is done by updating the docker compose file. Similarly, a new compose project is created for the runner.

![GitHub Selective Mirroring Runner Config](../artifacts/gitea/2026-11-11_Gitea_GitHub-Mirroring_Runner-Config.png)

![GitHub Selective Mirroring Secret Config](../artifacts/gitea/2026-11-11_Gitea_GitHub-Mirroring_Secret-Config.png)

![GitHub Selective Mirroring Runner Action Validation](../artifacts/gitea/2026-11-11_Gitea_GitHub-Mirroring_Runner-Push.png)

![GitHub Selective Mirroring GitHub Push Validation](../artifacts/gitea/2026-11-11_Gitea_GitHub-Mirroring_Runner-Push-GitHub-Validation.png)

With the basic push to main validated, the `deploy/gitea` branch was pushed to the Gitlab Remote. It was confirmed that this didn't trigger the runner, and the branch wasn't pushed to GitHub.


![GitHub Selective Mirroring Feature Branch](../artifacts/gitea/2026-11-11_Gitea_GitHub-Mirroring_Runner-Push-gitlab-branch.png)

![GitHub Selective Mirroring Feature Branch Validation](../artifacts/gitea/2026-11-11_Gitea_GitHub-Mirroring_Runner-Push-gitlab-branch-GitHub-Validation.png)

## 4. Outcome & Future Considerations

* **Result:** Gitea is successfully deployed as the primary Git remote and CI/CD control plane, isolated behind Authentik OIDC and Traefik SSL.

* **Result:** SSH Git operations are successfully proxied through Traefik's TCP routing with Client IP preservation (Proxy Protocol v2).

* **Result:** GitHub is successfully decoupled from execution. It now functions strictly as a sanitized, read-only portfolio updated automatically via Gitea push mirroring.

* **Result:** All historical issues and labels have been successfully centralized into the local Gitea instance.

### Next Steps

* [x] **Completed:** Deploy Gitea, OIDC authentication, and Traefik TCP routing.
* [x] **Completed:** Validate Gitea-to-GitHub selective push mirroring via Gitea Actions.
* [ ] **Pending:** Merge `deploy/gitea` to `main` via Squash-Merge to trigger the first automated mirror sync of the new architecture.
* [ ] **Pending:** Proceed to Phase 2 of the CI/CD pipeline migration: Secrets Centralization (Infisical).
