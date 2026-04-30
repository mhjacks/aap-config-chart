{{/*
Vault TLS CA for Vault CSI (same lookup sources as openshift-external-secrets / openshift-sscsi-vault sync).

Rendered only from aap-config-chart so Argo works with published openshift-sscsi-vault versions that
do not ship openshift_sscsi_vault.syncVaultCsiTlsCaConfigMapYaml.

Requires helm against a live API (lookup). When empty, omit ConfigMap and do not set vaultCACertPath.
*/}}
{{- define "aap_config.vaultTlsCaPemFromCluster" -}}
{{- $cap := .Values.ocpSecretsStoreCsiVault.caProvider | default dict }}
{{- $sync := $cap.syncProviderCaConfigMap | default dict }}
{{- if default false $sync.enabled }}
{{- $hashicorp_vault_found := false }}
{{- if and .Values.clusterGroup .Values.clusterGroup.applications }}
{{- range $_, $app := .Values.clusterGroup.applications }}
  {{- if $app }}
    {{- if eq $app.chart "hashicorp-vault" }}
      {{- $hashicorp_vault_found = true }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- $isHubStyleAuth := or (eq (include "openshift_sscsi_vault.ishubcluster" .) "true") $hashicorp_vault_found }}
{{- $preset := $sync.preset | default "auto" | trim | lower }}
{{- if eq $preset "auto" }}
  {{- if $isHubStyleAuth }}
    {{- $preset = "ingressrouterca" }}
  {{- else }}
    {{- $preset = "esospokehubca" }}
  {{- end }}
{{- end }}
{{- if eq $preset "ingressrouterca" }}
  {{- $ref := $sync.ingressRouterCa | default dict }}
  {{- $ns := $ref.namespace | default "openshift-ingress" }}
  {{- $name := $ref.name | default "router-ca" }}
  {{- $key := $ref.key | default "ca-bundle.crt" }}
  {{- $obj := lookup "v1" "ConfigMap" $ns $name }}
  {{- if and $obj (hasKey $obj.data $key) }}{{- index $obj.data $key -}}{{- end }}
{{- else if eq $preset "esohubkuberootca" }}
  {{- $hc := $cap.hostCluster | default dict }}
  {{- $ns := $hc.namespace | default "external-secrets" }}
  {{- $name := $hc.name | default "kube-root-ca.crt" }}
  {{- $key := $hc.key | default "ca.crt" }}
  {{- $obj := lookup "v1" "ConfigMap" $ns $name }}
  {{- if and $obj (hasKey $obj.data $key) }}{{- index $obj.data $key -}}{{- end }}
{{- else if eq $preset "esospokehubca" }}
  {{- $cc := $cap.clientCluster | default dict }}
  {{- $ns := $cc.namespace | default "external-secrets" }}
  {{- $name := $cc.name | default "hub-ca" }}
  {{- $key := $cc.key | default "hub-kube-root-ca.crt" }}
  {{- $obj := lookup "v1" "Secret" $ns $name }}
  {{- if and $obj (hasKey $obj.data $key) }}{{- index $obj.data $key | b64dec -}}{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "aap_config.syncVaultCsiTlsCaConfigMapYaml" -}}
{{- $cap := .Values.ocpSecretsStoreCsiVault.caProvider | default dict }}
{{- $sync := $cap.syncProviderCaConfigMap | default dict }}
{{- if default false $sync.enabled }}
{{- $pem := trim (include "aap_config.vaultTlsCaPemFromCluster" .) }}
{{- if ne $pem "" }}
{{- $cmName := $sync.configMapName | default "" | trim }}
{{- if eq $cmName "" }}
{{- $cmName = "openshift-sscsi-vault-vault-tls-ca" }}
{{- end }}
{{- $targetNs := $sync.targetNamespace | default "vault" | trim }}
{{- $keyFile := $sync.keyInConfigMap | default "vault-tls-ca.pem" | trim }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $cmName | quote }}
  namespace: {{ $targetNs | quote }}
  labels:
    app.kubernetes.io/name: aap-config
    app.kubernetes.io/component: vault-csi-tls-ca
data:
  {{ $keyFile | quote }}: |
{{ $pem | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}
