# aap-config

![Version: 0.2.7](https://img.shields.io/badge/Version-0.2.7-informational?style=flat-square)

A Helm chart to build and deploy secrets using external-secrets for ansible-edge-gitops

This chart is used to set up the Ansible Automation Platform Operator version 2.5.

### Notable changes

* v0.1.2: Introduce EXTRA_PLAYBOOK_OPTS to config job, to allow for extra vars and
-v options (usually -vvv) to be passed to playbook to help debug it

* v0.1.3: Introduce "bootstrap" phase; this means that the config job will run until
it succeeds, and only then proceed to create the cronjob to re-configure. It also
means the cronjob scheduling is nowehere near as aggressive (every even hour at
the 10-minute mark instead of every ten minutes as previously).

* v0.1.4: Use vp-rbac subchart to configure RBACs instead of local code. Introduce
external secrets validation job to prevent argo from proceeding past ES creation and
erroring out early.

* v0.1.5: Extend default deadline for external secret validation job. Remove
namespaces from external secrets validation.

* v0.2.0: **Breaking** External Secrets API Version updated to `v1` from `v1beta1`.
To use this version, you will also need to update your pattern to use the
`openshift-external-secrets-operator` and `openshift-external-secrets` helm chart.

* v0.2.1: Support credential (HTTPS or SSH) injection for git client in AGOF config
jobs.

* v0.2.2: Make agof-vault-file optional. Allow for skipping of the local Vault Hub
instance integration if desired.

* v0.2.3: Align with AGOF config-as-code naming and git authentication. Add
`agof.cac_repo` / `agof.cac_revision` (preferred over legacy `iac_repo` /
`iac_revision`). Git credential injection in init now covers both AGOF and the
config-as-code repo URL. The `helm-values` ConfigMap resolves legacy `iac_*`
into `cac_*` (and mirrors the result back to `iac_*` for current AGOF releases
that still read those keys). Requires a compatible AGOF revision (see agof
README OpenShift section).

* v0.2.4: Add `agof.gitHttpsSslVerify` to disable TLS verification for HTTPS
git operations when `agof_repo` or the config-as-code repo uses an untrusted or
private CA (lab use only). Applies to the init-container AGOF clone and is passed
through to AGOF for the config-as-code checkout.

* v0.2.5: Fix `helm-values` ConfigMap resolution so `cac_repo` / `cac_revision`
are the canonical fields. Legacy `iac_*` values merge into `cac_*` when `cac_*`
is unset or left at chart defaults; when `cac_*` is explicitly set, it wins over
`iac_*`.

* v0.2.6: Track v3 of AGOF by default

* v0.2.7: Reconfigure external secrets validation retries. Add configurable
`validationJob.backoffLimit` (default 20) and reduce `validationJob.activeDeadlineSeconds`
to 600 (10 min). Run the validation job as an Argo Sync hook at sync-wave 2 with
`HookSucceeded,BeforeHookCreation` so ExternalSecrets apply in wave 1 before
validation runs and each sync retry gets a fresh job without OutOfSync drift.

### Git authentication secret (`agof.gitAuthSecret`)

When `agof_repo` or the config-as-code repo (`agof.cac_repo` / `agof.iac_repo`) is
private, set `agof.gitAuthSecret` to the name of a Kubernetes Secret in the same
namespace. The init container mounts that Secret and configures git before cloning
AGOF. Use **one** authentication shape per Secret; the chart checks mechanisms in
this order: `.git-credentials`, then `ssh-privatekey`, then HTTPS
`username`/`password`/`token`.

Pattern Helm values:

```yaml
agof:
  gitAuthSecret: git-auth-secret
  # Optional: populate the Secret from Vault via External Secrets (VP-Secrets-v2 below)
  gitAuthVaultKey: secret/data/hub/git-auth-secret
  # Used only for token-only HTTPS Secrets (see examples)
  gitAuthHttpsStyle: auto   # auto | github | gitlab | gitea
```

### HTTPS TLS verification (`agof.gitHttpsSslVerify`)

By default, HTTPS git operations validate the server TLS certificate against the
container trust store. When `agof_repo` or the config-as-code repo
(`agof.cac_repo` / `agof.iac_repo`) is served by a host with a private or
corporate CA that is not installed in the image, set:

```yaml
agof:
  gitHttpsSslVerify: false
```

This disables certificate verification for the init-container clone of AGOF and
for the config-as-code repo checkout during `configure_aap`. Prefer installing the
CA in the container image or on the provisioner for production.

#### HTTPS: pre-built `.git-credentials` store

Secret key `.git-credentials` is copied to `~/.git-credentials` and used with
`credential.helper store`. One line per host; credentials apply to both AGOF and
the config-as-code repo when the host matches.

VP-Secrets-v2:

```yaml
  - name: git-auth-secret
    fields:
    - name: .git-credentials
      value: |
        https://x-access-token:ghp_xxxxxxxxxxxxxxxxxxxx@github.com
```

Multiple hosts (GitLab, Forgejo, etc.):

```yaml
  - name: git-auth-secret
    fields:
    - name: .git-credentials
      value: |
        https://oauth2:glpat-xxxxxxxxxxxxxxxxxxxx@gitlab.com
        https://my-gitea-user:0123456789abcdef0123456789abcdef01234567@forgejo.example.com
```

#### HTTPS: `username` + `password` or `token`

The init container writes a git credential-store entry for each unique host parsed
from `agof_repo` and the config-as-code repo URL.

Username and password:

```yaml
  - name: git-auth-secret
    fields:
    - name: username
      value: my-gitea-user
    - name: password
      value: my-secret-password
```

Username and token (PAT / deploy token):

```yaml
  - name: git-auth-secret
    fields:
    - name: username
      value: x-access-token
    - name: token
      value: ghp_xxxxxxxxxxxxxxxxxxxx
```

#### HTTPS: `token` only

When the Secret has a `token` key but no `username`, the chart picks the HTTPS
username from `agof.gitAuthHttpsStyle` and the repo host (`auto`: GitHub → `git`,
GitLab / Gitea / Forgejo / Codeberg → `oauth2`, otherwise `git`).

GitHub PAT:

```yaml
agof:
  gitAuthSecret: git-auth-secret
  gitAuthVaultKey: secret/data/hub/git-auth-secret
  gitAuthHttpsStyle: auto

secrets:
  - name: git-auth-secret
    fields:
    - name: token
      value: ghp_xxxxxxxxxxxxxxxxxxxx
```

GitLab project or group access token:

```yaml
  - name: git-auth-secret
    fields:
    - name: token
      value: glpat-xxxxxxxxxxxxxxxxxxxx
```

Force a platform username when `auto` does not match your host (for example a
self-managed GitLab hostname):

```yaml
agof:
  gitAuthSecret: git-auth-secret
  gitAuthHttpsStyle: gitlab

secrets:
  - name: git-auth-secret
    fields:
    - name: token
      value: glpat-xxxxxxxxxxxxxxxxxxxx
```

#### SSH: `ssh-privatekey` (+ optional `known_hosts`)

Secret key `ssh-privatekey` is installed as `~/.ssh/id_rsa`. When `known_hosts` is
present it is copied to `~/.ssh/known_hosts` and SSH uses strict host key
checking. When `known_hosts` is omitted, SSH uses `StrictHostKeyChecking=accept-new`
for the clone.

Deploy key with pinned host key (recommended):

```yaml
  - name: git-auth-secret
    fields:
    - name: ssh-privatekey
      path: /path/to/deploy_key   # or use value: with inline PEM/OpenSSH key
    - name: known_hosts
      value: |
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...
      # obtain with: ssh-keyscan -t ed25519 github.com
```

Deploy key without `known_hosts` (accepts the host key on first connect):

```yaml
  - name: git-auth-secret
    fields:
    - name: ssh-privatekey
      value: |
        -----BEGIN OPENSSH PRIVATE KEY-----
        ...
        -----END OPENSSH PRIVATE KEY-----
```

Self-managed Forgejo / Gitea:

```yaml
  - name: git-auth-secret
    fields:
    - name: ssh-privatekey
      path: /path/to/forgejo_deploy_key
    - name: known_hosts
      value: |
        forgejo.example.com ssh-ed25519 AAAA...
```

You can also create the Secret directly (for example `kubernetes.io/ssh-auth`) as
long as the data keys are `ssh-privatekey` and optionally `known_hosts`, and
`agof.gitAuthSecret` points at that Secret name.

### VP-Secrets-v2

```yaml
---
# NEVER COMMIT THESE VALUES TO GIT
version: "2.0"
secrets:
  - name: aap-manifest
    fields:
    - name: b64content
      path: 'full pathname of file containing Satellite Manifest for entitling Ansible Automation Platform'
      base64: true

  - name: automation-hub-token
    fields:
    - name: token
      value: 'An automation hub token for retrieving Certified and Validated Ansible content'

  # Optional
  - name: agof-vault-file
    fields:
    - name: agof-vault-file
      path: 'full pathname of a valid agof_vault file for secrets to overlay the iac config'
      base64: true

  # Optional: private git auth for agof_repo and/or config-as-code repo (see section above)
  - name: git-auth-secret
    fields:
    - name: token
      value: ghp_xxxxxxxxxxxxxxxxxxxx
```

**Homepage:** <https://github.com/validatedpatterns/aap-config-chart.git>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.validatedpatterns.io | vp-rbac | 0.1.* |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| aapManifest.key | string | `"secret/data/hub/aap-manifest"` |  |
| agof.agof_repo | string | `"https://github.com/validatedpatterns/agof.git"` |  |
| agof.agof_revision | string | `"v3"` |  |
| agof.automationHubTokenKey | string | `"secret/data/hub/automation-hub-token"` |  |
| agof.cac_repo | string | `"https://github.com/validatedpatterns-demos/ansible-edge-gitops-hmi-config-as-code.git"` |  |
| agof.cac_revision | string | `"main"` |  |
| agof.doAutoHubVaultConfig | bool | `true` |  |
| agof.extraPlaybookOpts | string | `""` |  |
| agof.gitAuthHttpsStyle | string | `"auto"` |  |
| agof.gitAuthSecret | string | `""` |  |
| agof.gitAuthVaultKey | string | `""` |  |
| agof.gitHttpsSslVerify | bool | `true` |  |
| agof.iac_repo | string | `""` |  |
| agof.iac_revision | string | `""` |  |
| agof.vaultFileKey | string | `""` |  |
| configJob.activeDeadlineSeconds | int | `3600` |  |
| configJob.configTimeout | int | `1800` |  |
| configJob.image | string | `"quay.io/hybridcloudpatterns/imperative-container:v1"` |  |
| configJob.imagePullPolicy | string | `"Always"` |  |
| configJob.schedule | string | `"10 */2 * * *"` |  |
| secretStore.kind | string | `"ClusterSecretStore"` |  |
| secretStore.name | string | `"vault-backend"` |  |
| serviceAccountName | string | `"aap-config-sa"` |  |
| serviceAccountNamespace | string | `"aap-config"` |  |
| validationJob.activeDeadlineSeconds | int | `600` |  |
| validationJob.backoffLimit | int | `20` |  |
| validationJob.disabled | bool | `false` |  |
| vp-rbac.clusterRoles.view-routes.rules[0].apiGroups[0] | string | `"route.openshift.io"` |  |
| vp-rbac.clusterRoles.view-routes.rules[0].resources[0] | string | `"routes"` |  |
| vp-rbac.clusterRoles.view-routes.rules[0].verbs[0] | string | `"get"` |  |
| vp-rbac.clusterRoles.view-routes.rules[0].verbs[1] | string | `"list"` |  |
| vp-rbac.clusterRoles.view-routes.rules[0].verbs[2] | string | `"watch"` |  |
| vp-rbac.clusterRoles.view-secrets-cms.rules[0].apiGroups[0] | string | `""` |  |
| vp-rbac.clusterRoles.view-secrets-cms.rules[0].resources[0] | string | `"secrets"` |  |
| vp-rbac.clusterRoles.view-secrets-cms.rules[0].resources[1] | string | `"configmaps"` |  |
| vp-rbac.clusterRoles.view-secrets-cms.rules[0].verbs[0] | string | `"get"` |  |
| vp-rbac.clusterRoles.view-secrets-cms.rules[0].verbs[1] | string | `"list"` |  |
| vp-rbac.clusterRoles.view-secrets-cms.rules[0].verbs[2] | string | `"watch"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].apiGroups[0] | string | `"external-secrets.io"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].resources[0] | string | `"externalsecrets"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].verbs[0] | string | `"get"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].verbs[1] | string | `"list"` |  |
| vp-rbac.roles.external-secrets-validator.rules[0].verbs[2] | string | `"watch"` |  |
| vp-rbac.roles.external-secrets-validator.rules[1].apiGroups[0] | string | `""` |  |
| vp-rbac.roles.external-secrets-validator.rules[1].resources[0] | string | `"secrets"` |  |
| vp-rbac.roles.external-secrets-validator.rules[1].verbs[0] | string | `"get"` |  |
| vp-rbac.roles.external-secrets-validator.rules[1].verbs[1] | string | `"list"` |  |
| vp-rbac.roles.external-secrets-validator.rules[1].verbs[2] | string | `"watch"` |  |
| vp-rbac.roles.external-secrets-validator.rules[2].apiGroups[0] | string | `"authorization.k8s.io"` |  |
| vp-rbac.roles.external-secrets-validator.rules[2].resources[0] | string | `"selfsubjectrulesreviews"` |  |
| vp-rbac.roles.external-secrets-validator.rules[2].verbs[0] | string | `"create"` |  |
| vp-rbac.roles.view-all.rules[0].apiGroups[0] | string | `"*"` |  |
| vp-rbac.roles.view-all.rules[0].resources[0] | string | `"*"` |  |
| vp-rbac.roles.view-all.rules[0].verbs[0] | string | `"get"` |  |
| vp-rbac.roles.view-all.rules[0].verbs[1] | string | `"list"` |  |
| vp-rbac.roles.view-all.rules[0].verbs[2] | string | `"watch"` |  |
| vp-rbac.serviceAccounts.aap-config-sa.namespace | string | `"aap-config"` |  |
| vp-rbac.serviceAccounts.aap-config-sa.roleBindings.clusterRoles[0] | string | `"view-secrets-cms"` |  |
| vp-rbac.serviceAccounts.aap-config-sa.roleBindings.clusterRoles[1] | string | `"view-routes"` |  |
| vp-rbac.serviceAccounts.aap-config-sa.roleBindings.roles[0] | string | `"view-all"` |  |
| vp-rbac.serviceAccounts.aap-config-sa.roleBindings.roles[1] | string | `"external-secrets-validator"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
