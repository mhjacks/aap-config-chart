# aap-config

![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square)

A Helm chart to build and deploy secrets using external-secrets for ansible-edge-gitops

This chart is used to set up the Ansible Automation Platform Operator version 2.5.

### Notable changes

* v0.1.2: Introduce EXTRA_PLAYBOOK_OPTS to config job, to allow for extra vars and
-v options (usually -vvv) to be passed to playbook to help debug it

* v0.1.3: Introduce "bootstrap" phase; this means that the config job will run until
it succeeds, and only then proceed to create the cronjob to re-configure.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| aapManifest.key | string | `"secret/data/hub/aap-manifest"` |  |
| agof.agof_repo | string | `"https://github.com/validatedpatterns/agof.git"` |  |
| agof.agof_revision | string | `"v2"` |  |
| agof.automationHubTokenKey | string | `"secret/data/hub/automation-hub-token"` |  |
| agof.extraPlaybookOpts | string | `""` |  |
| agof.iac_repo | string | `"https://github.com/validatedpatterns-demos/ansible-edge-gitops-hmi-config-as-code.git"` |  |
| agof.iac_revision | string | `"main"` |  |
| agof.vaultFileKey | string | `"secret/data/hub/agof-vault-file"` |  |
| configJob.activeDeadlineSeconds | int | `3600` |  |
| configJob.configTimeout | int | `1800` |  |
| configJob.image | string | `"quay.io/hybridcloudpatterns/imperative-container:v1"` |  |
| configJob.imagePullPolicy | string | `"Always"` |  |
| configJob.schedule | string | `"10 */2 * * *"` |  |
| rbac.roleBindings[0].createBinding | bool | `true` |  |
| rbac.roleBindings[0].name | string | `"view-aap-secrets-cms"` |  |
| rbac.roleBindings[0].roleRef.kind | string | `"ClusterRole"` |  |
| rbac.roleBindings[0].roleRef.name | string | `"view-secrets-cms"` |  |
| rbac.roleBindings[0].scope.cluster | bool | `false` |  |
| rbac.roleBindings[0].scope.namespace | string | `"ansible-automation-platform"` |  |
| rbac.roleBindings[0].subjects.apiGroup | string | `""` |  |
| rbac.roleBindings[0].subjects.kind | string | `"ServiceAccount"` |  |
| rbac.roleBindings[0].subjects.name | string | `"aap-config-sa"` |  |
| rbac.roleBindings[0].subjects.namespace | string | `"aap-config"` |  |
| rbac.roleBindings[1].createBinding | bool | `true` |  |
| rbac.roleBindings[1].name | string | `"view-aap-routes"` |  |
| rbac.roleBindings[1].roleRef.kind | string | `"ClusterRole"` |  |
| rbac.roleBindings[1].roleRef.name | string | `"view-routes"` |  |
| rbac.roleBindings[1].scope.cluster | bool | `false` |  |
| rbac.roleBindings[1].scope.namespace | string | `"ansible-automation-platform"` |  |
| rbac.roleBindings[1].subjects.apiGroup | string | `""` |  |
| rbac.roleBindings[1].subjects.kind | string | `"ServiceAccount"` |  |
| rbac.roleBindings[1].subjects.name | string | `"aap-config-sa"` |  |
| rbac.roleBindings[1].subjects.namespace | string | `"aap-config"` |  |
| rbac.roleBindings[2].createBinding | bool | `true` |  |
| rbac.roleBindings[2].name | string | `"view-vault-secrets-cms"` |  |
| rbac.roleBindings[2].roleRef.kind | string | `"ClusterRole"` |  |
| rbac.roleBindings[2].roleRef.name | string | `"view-secrets-cms"` |  |
| rbac.roleBindings[2].scope.cluster | bool | `false` |  |
| rbac.roleBindings[2].scope.namespace | string | `"vault"` |  |
| rbac.roleBindings[2].subjects.apiGroup | string | `""` |  |
| rbac.roleBindings[2].subjects.kind | string | `"ServiceAccount"` |  |
| rbac.roleBindings[2].subjects.name | string | `"aap-config-sa"` |  |
| rbac.roleBindings[2].subjects.namespace | string | `"aap-config"` |  |
| rbac.roleBindings[3].createBinding | bool | `true` |  |
| rbac.roleBindings[3].name | string | `"view-imperative-secrets-cms"` |  |
| rbac.roleBindings[3].roleRef.kind | string | `"ClusterRole"` |  |
| rbac.roleBindings[3].roleRef.name | string | `"view-secrets-cms"` |  |
| rbac.roleBindings[3].scope.cluster | bool | `false` |  |
| rbac.roleBindings[3].scope.namespace | string | `"imperative"` |  |
| rbac.roleBindings[3].subjects.apiGroup | string | `""` |  |
| rbac.roleBindings[3].subjects.kind | string | `"ServiceAccount"` |  |
| rbac.roleBindings[3].subjects.name | string | `"aap-config-sa"` |  |
| rbac.roleBindings[3].subjects.namespace | string | `"aap-config"` |  |
| rbac.roleBindings[4].createBinding | bool | `true` |  |
| rbac.roleBindings[4].name | string | `"view-all"` |  |
| rbac.roleBindings[4].roleRef.kind | string | `"Role"` |  |
| rbac.roleBindings[4].roleRef.name | string | `"view-all"` |  |
| rbac.roleBindings[4].scope.cluster | bool | `false` |  |
| rbac.roleBindings[4].scope.namespace | string | `"aap-config"` |  |
| rbac.roleBindings[4].subjects.apiGroup | string | `""` |  |
| rbac.roleBindings[4].subjects.kind | string | `"ServiceAccount"` |  |
| rbac.roleBindings[4].subjects.name | string | `"aap-config-sa"` |  |
| rbac.roleBindings[4].subjects.namespace | string | `"aap-config"` |  |
| rbac.roles[0].apiGroups[0] | string | `"\"\""` |  |
| rbac.roles[0].createRole | bool | `true` |  |
| rbac.roles[0].name | string | `"view-secrets-cms"` |  |
| rbac.roles[0].resources[0] | string | `"secrets"` |  |
| rbac.roles[0].resources[1] | string | `"configmaps"` |  |
| rbac.roles[0].scope.cluster | bool | `true` |  |
| rbac.roles[0].verbs[0] | string | `"get"` |  |
| rbac.roles[0].verbs[1] | string | `"list"` |  |
| rbac.roles[0].verbs[2] | string | `"watch"` |  |
| rbac.roles[1].apiGroups[0] | string | `"route.openshift.io"` |  |
| rbac.roles[1].createRole | bool | `true` |  |
| rbac.roles[1].name | string | `"view-routes"` |  |
| rbac.roles[1].resources[0] | string | `"routes"` |  |
| rbac.roles[1].scope.cluster | bool | `true` |  |
| rbac.roles[1].verbs[0] | string | `"get"` |  |
| rbac.roles[1].verbs[1] | string | `"list"` |  |
| rbac.roles[1].verbs[2] | string | `"watch"` |  |
| rbac.roles[2].apiGroups[0] | string | `"\"*\""` |  |
| rbac.roles[2].createRole | bool | `true` |  |
| rbac.roles[2].name | string | `"view-all"` |  |
| rbac.roles[2].resources[0] | string | `"\"*\""` |  |
| rbac.roles[2].scope.cluster | bool | `false` |  |
| rbac.roles[2].verbs[0] | string | `"get"` |  |
| rbac.roles[2].verbs[1] | string | `"list"` |  |
| rbac.roles[2].verbs[2] | string | `"watch"` |  |
| secretStore.kind | string | `"ClusterSecretStore"` |  |
| secretStore.name | string | `"vault-backend"` |  |
| serviceAccountName | string | `"aap-config-sa"` |  |
| serviceAccountNamespace | string | `"aap-config"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
