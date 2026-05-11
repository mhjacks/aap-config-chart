# aap-config

![Version: 0.3.1](https://img.shields.io/badge/Version-0.3.1-informational?style=flat-square)

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

* v0.2.10: Optional Vault CSI path for the AAP manifest (`aapManifest.csi` + **`openshift-sscsi-vault`** subchart): SecretProviderClass, workload RBAC, and TLS CA sync aligned with **`openshift-sscsi-vault` 0.0.12+** (`renderSyncCaConfigMap`). For Argo CD, supply CA PEM via **`openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.pemLiteral`** (**`openshift-sscsi-vault` 0.0.13+**) or manage the ConfigMap out-of-band; do not rely on **`helm lookup()`** under client-side manifest render.

* v0.2.11: Packaged **`openshift-sscsi-vault`** values default to **`injectTrustedCabundle: true`**, **`createConfigMap: true`**, and **`trustedCabundleDataKey: ca-bundle.crt`** (CNO-injected trust bundle, **`openshift-sscsi-vault` 0.0.15+**). Set **`injectTrustedCabundle: false`** and **`pemLiteral`** (or legacy Ansible CM with **`createConfigMap: false`**) when not using cluster injection.

* v0.3.0: **Breaking (CSI)** — Replaced embedded **`openshift-sscsi-vault`** library dependency with **`vp-sscsi-spc`** (Validated Patterns) calling conventions from **multicloud-gitops** `config-demo`: root **`ocpSecretsStoreCsiVault`**, stub **`vp-sscsi-spc`** values to disable bundled output, and **`include "vp_sscsi_spc.secretproviderclass"`** only. TLS CA ConfigMap sync and **`ClusterRoleBinding`** for the CSI provider live in the **cluster** **`openshift-sscsi-vault`** application (e.g. **0.2.***); this chart emits the **SecretProviderClass** only. Pattern **`clusterGroup.applications[applicationKey].ssCsiWorkloadAuth`** (default **`applicationKey: aap-config`**, i.e. auth under the **aap-config** application, not the vault cluster app) supplies workload namespace / SA / role slug; use **`csiWorkloadIdentity`** to synthesize that block. SPC TLS uses **`tls.projectedClusterCa`** (or explicit **`vaultCACertPath`**) aligned with the provider mount.

* v0.3.1: **CSI** — The **`vp-sscsi-spc`** dependency now renders the **SecretProviderClass** via its **`installDefaultManifests`** template (same **`vp_sscsi_spc.secretproviderclass`** library); root **`ocpSecretsStoreCsiVault`** and **`clusterGroup`** are duplicated under **`vp-sscsi-spc`** so the subchart receives **`clusterGroup`** (Helm does not pass parent-only keys into dependencies). Any future bundled manifests from **`vp-sscsi-spc`** (for example a workload ConfigMap) ship with that chart automatically. **`csiWorkloadIdentity`**: set **`vp-sscsi-spc.ocpSecretsStoreCsiVault.secretProviderClass.installDefaultManifests`** to **`false`** so the parent template can still render the SPC with synthesized **`ssCsiWorkloadAuth`**.

### Vault CSI manifest (`aapManifest.csi`)

When **`aapManifest.csi.enabled`** is true, this chart depends on **`vp-sscsi-spc`**, which renders the Vault **`SecretProviderClass`** from **`charts/vp-sscsi-spc/templates/install-default-manifests.yaml`** when **`vp-sscsi-spc.ocpSecretsStoreCsiVault.secretProviderClass.installDefaultManifests`** is **`true`** (default). Configure **`objects`**, **`tls`**, **`auth`**, and **`secretProviderClass`** metadata on root **`ocpSecretsStoreCsiVault`**; keep **`vp-sscsi-spc.ocpSecretsStoreCsiVault`** in sync with that block (values defaults duplicate it) so the dependency sees **`clusterGroup`** and **`ocpSecretsStoreCsiVault`**. **`vp-sscsi-spc.clusterGroup`** aliases root **`clusterGroup`** via a YAML anchor so **`ssCsiWorkloadAuth`** stays aligned. If **`csiWorkloadIdentity.enabled`** is **`true`**, set **`vp-sscsi-spc.ocpSecretsStoreCsiVault.secretProviderClass.installDefaultManifests`** to **`false`** so the parent **`templates/aap-manifest-vault-csi.yaml`** renders the SPC with merged **`clusterGroup`**. Deploy the cluster **`openshift-sscsi-vault`** chart separately so the Vault CSI DaemonSet mounts the TLS CA bundle (**ConfigMap** sync for the provider) and token-review RBAC exists. Optional init **`aap-manifest-vault-tls-check`** probes Vault HTTPS when TLS verify is on.

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

  # Optional, if git auth is needed
  - name: git-auth-secret
    fields:
    # HTTPS auth
    - name: username
      value: "Username to authenticate with"
    - value: password
      value: "Password to authenticate with"
    # SSH auth
    - name: .git-credentials
      value: "git credentials"
    - name: ssh-privatekey
      value: "An ssh private key"
    - name: known_hosts
      value: "SSH known hosts for SSH authentication"
```

**Homepage:** <https://github.com/validatedpatterns/aap-config-chart.git>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.validatedpatterns.io | vp-rbac | 0.1.* |
| https://charts.validatedpatterns.io | vp-sscsi-spc | 0.1.* |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| aapManifest.csi.enabled | bool | `false` |  |
| aapManifest.csi.mountPath | string | `"/pattern-home/aap-manifest"` |  |
| aapManifest.csi.objectName | string | `"b64content"` |  |
| aapManifest.csi.secretProviderClassName | string | `"aap-manifest-vault"` |  |
| aapManifest.csi.vaultTlsCheck.caBundlePath | string | `"/etc/pki/tls/certs/ca-bundle.crt"` |  |
| aapManifest.csi.vaultTlsCheck.connectTimeoutSeconds | int | `10` |  |
| aapManifest.csi.vaultTlsCheck.enabled | bool | `true` |  |
| aapManifest.csi.vaultTlsCheck.maxTimeSeconds | int | `60` |  |
| aapManifest.key | string | `"secret/data/hub/aap-manifest"` |  |
| agof.agof_repo | string | `"https://github.com/validatedpatterns/agof.git"` |  |
| agof.agof_revision | string | `"v2"` |  |
| agof.automationHubTokenKey | string | `"secret/data/hub/automation-hub-token"` |  |
| agof.doAutoHubVaultConfig | bool | `true` |  |
| agof.extraPlaybookOpts | string | `""` |  |
| agof.gitAuthHttpsStyle | string | `"auto"` |  |
| agof.gitAuthSecret | string | `""` |  |
| agof.gitAuthVaultKey | string | `""` |  |
| agof.iac_repo | string | `"https://github.com/validatedpatterns-demos/ansible-edge-gitops-hmi-config-as-code.git"` |  |
| agof.iac_revision | string | `"main"` |  |
| agof.vaultFileKey | string | `""` |  |
| clusterGroup.applications | object | `{}` |  |
| configJob.activeDeadlineSeconds | int | `3600` |  |
| configJob.configTimeout | int | `1800` |  |
| configJob.image | string | `"quay.io/hybridcloudpatterns/imperative-container:v1"` |  |
| configJob.imagePullPolicy | string | `"Always"` |  |
| configJob.schedule | string | `"10 */2 * * *"` |  |
| csiWorkloadIdentity.appKey | string | `"aap-config"` |  |
| csiWorkloadIdentity.enabled | bool | `false` |  |
| csiWorkloadIdentity.namespace | string | `""` |  |
| csiWorkloadIdentity.serviceAccount | string | `""` |  |
| csiWorkloadIdentity.vaultAuthMount | string | `"hub"` |  |
| csiWorkloadIdentity.vaultKubernetesAuthRole | string | `""` |  |
| global.clusterDomain | string | `"foo.example.com"` |  |
| global.hubClusterDomain | string | `"hub.example.com"` |  |
| global.localClusterDomain | string | `""` |  |
| ocpSecretsStoreCsiVault.applicationKey | string | `"aap-config"` |  |
| ocpSecretsStoreCsiVault.auth.roleName | string | `"hub-role"` |  |
| ocpSecretsStoreCsiVault.objects[0].objectName | string | `"b64content"` |  |
| ocpSecretsStoreCsiVault.objects[0].secretKey | string | `"b64content"` |  |
| ocpSecretsStoreCsiVault.objects[0].secretPath | string | `"secret/data/hub/aap-manifest"` |  |
| ocpSecretsStoreCsiVault.secretObjects | list | `[]` |  |
| ocpSecretsStoreCsiVault.secretProviderClass.enabled | bool | `true` |  |
| ocpSecretsStoreCsiVault.secretProviderClass.installDefaultManifests | bool | `false` |  |
| ocpSecretsStoreCsiVault.secretProviderClass.name | string | `"aap-manifest-vault"` |  |
| ocpSecretsStoreCsiVault.secretProviderClass.namespace | string | `"aap-config"` |  |
| ocpSecretsStoreCsiVault.tls.projectedClusterCa.enabled | bool | `true` |  |
| ocpSecretsStoreCsiVault.tls.projectedClusterCa.injectTrustedCabundle | bool | `true` |  |
| ocpSecretsStoreCsiVault.tls.projectedClusterCa.keyInConfigMap | string | `"vault-tls-ca.pem"` |  |
| ocpSecretsStoreCsiVault.tls.projectedClusterCa.mountDir | string | `"/etc/pki/vault-ca"` |  |
| ocpSecretsStoreCsiVault.tls.projectedClusterCa.trustedCabundleDataKey | string | `"ca-bundle.crt"` |  |
| ocpSecretsStoreCsiVault.tls.vaultCACertPath | string | `""` |  |
| ocpSecretsStoreCsiVault.tls.vaultSkipTLSVerify | string | `"false"` |  |
| ocpSecretsStoreCsiVault.tls.vaultTLSServerName | string | `""` |  |
| ocpSecretsStoreCsiVault.vault.externalAddress | string | `""` |  |
| ocpSecretsStoreCsiVault.vault.hubMountPath | string | `"hub"` |  |
| ocpSecretsStoreCsiVault.workloadAuthIndex | int | `0` |  |
| secretStore.kind | string | `"ClusterSecretStore"` |  |
| secretStore.name | string | `"vault-backend"` |  |
| serviceAccountName | string | `"aap-config-sa"` |  |
| serviceAccountNamespace | string | `"aap-config"` |  |
| validationJob.activeDeadlineSeconds | int | `3600` |  |
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
| vp-sscsi-spc.clusterGroup.applications | object | `{}` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.applicationKey | string | `"aap-config"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.auth.roleName | string | `"hub-role"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.objects[0].objectName | string | `"b64content"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.objects[0].secretKey | string | `"b64content"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.objects[0].secretPath | string | `"secret/data/hub/aap-manifest"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.secretObjects | list | `[]` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.secretProviderClass.enabled | bool | `true` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.secretProviderClass.installDefaultManifests | bool | `true` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.secretProviderClass.name | string | `"aap-manifest-vault"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.secretProviderClass.namespace | string | `"aap-config"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.projectedClusterCa.enabled | bool | `true` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.projectedClusterCa.injectTrustedCabundle | bool | `true` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.projectedClusterCa.keyInConfigMap | string | `"vault-tls-ca.pem"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.projectedClusterCa.mountDir | string | `"/etc/pki/vault-ca"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.projectedClusterCa.trustedCabundleDataKey | string | `"ca-bundle.crt"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.vaultCACertPath | string | `""` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.vaultSkipTLSVerify | string | `"false"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.tls.vaultTLSServerName | string | `""` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.vault.externalAddress | string | `""` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.vault.hubMountPath | string | `"hub"` |  |
| vp-sscsi-spc.ocpSecretsStoreCsiVault.workloadAuthIndex | int | `0` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
