# aap-config

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)

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

* v0.3.0: Allow for the creation of aap-manifest via SSCSI (which is now default)
or the classic ESO behavior.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.validatedpatterns.io | vp-rbac | 0.1.* |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| aapManifest.createExternalSecret | bool | `false` |  |
| aapManifest.externalSecret.mountPath | string | `"/pattern-home/aap-manifest"` |  |
| aapManifest.externalSecret.secretName | string | `"aap-manifest"` |  |
| aapManifest.key | string | `"secret/data/hub/aap-manifest"` |  |
| aapManifest.source | string | `"sscsi"` |  |
| aapManifest.sscsi.driver | string | `"secrets-store.csi.k8s.io"` |  |
| aapManifest.sscsi.mountPath | string | `"/pattern-home/aap-manifest"` |  |
| aapManifest.sscsi.secretProviderClass | string | `"aap-manifest"` |  |
| agof.agof_repo | string | `"https://github.com/validatedpatterns/agof.git"` |  |
| agof.agof_revision | string | `"v2"` |  |
| agof.automationHubTokenKey | string | `"secret/data/hub/automation-hub-token"` |  |
| agof.extraPlaybookOpts | string | `""` |  |
| agof.iac_repo | string | `"https://github.com/validatedpatterns-demos/ansible-edge-gitops-hmi-config-as-code.git"` |  |
| agof.iac_revision | string | `"main"` |  |
| agof.vaultFileEnabled | bool | `false` |  |
| agof.vaultFileKey | string | `"secret/data/hub/agof-vault-file"` |  |
| configJob.activeDeadlineSeconds | int | `3600` |  |
| configJob.configTimeout | int | `1800` |  |
| configJob.image | string | `"quay.io/hybridcloudpatterns/imperative-container:v1"` |  |
| configJob.imagePullPolicy | string | `"Always"` |  |
| configJob.schedule | string | `"10 */2 * * *"` |  |
| secretStore.kind | string | `"ClusterSecretStore"` |  |
| secretStore.name | string | `"vault-backend"` |  |
| serviceAccountName | string | `"aap-config-sa"` |  |
| serviceAccountNamespace | string | `"aap-config"` |  |
| validationJob.activeDeadlineSeconds | int | `3600` |  |
| validationJob.disabled | bool | `false` |  |
| validationJob.externalSecretsNamespace | string | `""` |  |
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
