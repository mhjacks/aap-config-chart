# aap-config

![Version: 0.2.10](https://img.shields.io/badge/Version-0.2.10-informational?style=flat-square)

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

### Vault CSI manifest (`aapManifest.csi`)

When **`aapManifest.csi.enabled`** is true, this chart depends on **`openshift-sscsi-vault`** and renders the Vault CSI SecretProviderClass and related RBAC using named templates from that chart. Set **`csiWorkloadIdentity`** when you want the workload identity fields merged into the SPC. TLS verification against the hub Vault route requires a CA file on the **Vault CSI provider** pod: the subchart can emit a ConfigMap from **`pemLiteral`** (GitOps-safe) or you can mount an existing ConfigMap; the HashiCorp Vault application should **`extraValueFiles`**-merge volumes that mount the same **`configMapName`** at **`syncProviderCaConfigMap.mountDir`** (see aap-starter-kit **`overrides/values-vault-csi-tls-ca.yaml`**).

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
| https://charts.validatedpatterns.io | openshift-sscsi-vault | 0.0.* |
| https://charts.validatedpatterns.io | vp-rbac | 0.1.* |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| aapManifest.csi.enabled | bool | `false` |  |
| aapManifest.csi.mountPath | string | `"/pattern-home/aap-manifest"` |  |
| aapManifest.csi.objectName | string | `"b64content"` |  |
| aapManifest.csi.secretProviderClassName | string | `"aap-manifest-vault"` |  |
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
| openshift-sscsi-vault.clusterGroup.applications | object | `{}` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.enabled | bool | `true` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.configMapName | string | `"openshift-sscsi-vault-vault-tls-ca"` | ConfigMap name; pattern `extraValueFiles` should mount this CM on the Vault CSI DaemonSet. |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.createConfigMap | bool | `true` | When false, subchart does not create the ConfigMap; supply and mount it yourself on the Vault CSI provider. |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.enabled | bool | `true` | Passed through to openshift-sscsi-vault: when true, TLS CA sync and SPC `vaultCACertPath` behavior apply. |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.keyInConfigMap | string | `"vault-tls-ca.pem"` | ConfigMap data key holding the PEM. |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.mountDir | string | `"/etc/pki/vault-ca"` | Mount directory on the Vault CSI provider pod for the CA PEM. |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.pemLiteral | string | `""` | Hub Vault route trust bundle (PEM). Required for Argo CD / client-side `helm template` when not using `useLookup`. |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.preset | string | `"auto"` | Preset for lookup-based CA resolution only (`auto`, `ingressrouterca`, etc.). |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.targetNamespace | string | `"vault"` | Namespace for the TLS CA ConfigMap (typically `vault` where the provider pod runs). |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.caProvider.syncProviderCaConfigMap.useLookup | bool | `false` | When true, subchart uses helm lookup() (needs API at render time; not for default Argo manifest generation). |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.objects[0].objectName | string | `"b64content"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.objects[0].secretKey | string | `"b64content"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.objects[0].secretPath | string | `"secret/data/hub/aap-manifest"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.rbac.rolename | string | `"hub-role"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.rbac.serviceAccount.create | bool | `false` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.rbac.serviceAccount.name | string | `"aap-config-sa"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.rbac.serviceAccount.namespace | string | `"aap-config"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.secretObjects | list | `[]` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.secretProviderClass.enabled | bool | `true` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.secretProviderClass.installDefaultManifests | bool | `false` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.secretProviderClass.name | string | `"aap-manifest-vault"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.tls.vaultCACertPath | string | `""` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.tls.vaultSkipTLSVerify | string | `"true"` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.tls.vaultTLSServerName | string | `""` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.vault.externalAddress | string | `""` |  |
| openshift-sscsi-vault.ocpSecretsStoreCsiVault.vault.hubMountPath | string | `"hub"` |  |
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

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
