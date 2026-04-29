{{- define "aap-config.manifestCsiEnabled" -}}
{{- if and $.Values.aapManifest.csi $.Values.aapManifest.csi.enabled }}true{{- else -}}false{{- end -}}
{{- end }}

{{/*
csiWorkloadIdentity: single source for CSI workload SA/namespace and Vault Kubernetes auth role name.
Slug matches rhvp.cluster_utils when vault_ss_csi_role_slug_mode is stable_slug (ns-sa-appKey).
If vaultKubernetesAuthRole is set, it is used as the full Vault role name (e.g. hub-sscsi-<sha1> for hash mode).
*/}}
{{- define "aap-config.csiWorkloadIdentityEnabled" -}}
{{- $id := $.Values.csiWorkloadIdentity | default dict -}}
{{- if and $id (eq true (default false $id.enabled)) }}true{{- else -}}false{{- end -}}
{{- end }}

{{- define "aap-config.effectiveServiceAccountName" -}}
{{- if eq (include "aap-config.csiWorkloadIdentityEnabled" $) "true" -}}
{{- required "csiWorkloadIdentity.serviceAccount is required when csiWorkloadIdentity.enabled" $.Values.csiWorkloadIdentity.serviceAccount -}}
{{- else -}}
{{- $.Values.serviceAccountName -}}
{{- end -}}
{{- end }}

{{- define "aap-config.effectiveServiceAccountNamespace" -}}
{{- if eq (include "aap-config.csiWorkloadIdentityEnabled" $) "true" -}}
{{- required "csiWorkloadIdentity.namespace is required when csiWorkloadIdentity.enabled" $.Values.csiWorkloadIdentity.namespace -}}
{{- else -}}
{{- $.Values.serviceAccountNamespace -}}
{{- end -}}
{{- end }}

{{/* Stable slug segment: lowercase alphanumerics joined by single hyphens (Ansible stable_slug). */}}
{{- define "aap-config.vaultSscsiSlug" -}}
{{- $s := printf "%s-%s-%s" .ns .sa .app | lower | regexReplaceAll "[^a-z0-9]+" "-" | regexReplaceAll "-+" "-" | trimAll "-" -}}
{{- $s -}}
{{- end }}

{{- define "aap-config.app.configjobspec" -}}
restartPolicy: Never
serviceAccountName: {{ include "aap-config.effectiveServiceAccountName" $ }}
volumes:
  - name: agof-scratch-space
    emptyDir:
      sizeLimit: 5Gi
{{- if $.Values.agof.vaultFileKey }}
  - name: agof-vault-file
    secret:
      secretName: agof-vault-file
{{- end }}
{{- if $.Values.agof.gitAuthSecret }}
  - name: agof-git-auth
    secret:
      secretName: {{ $.Values.agof.gitAuthSecret | quote }}
{{- end }}
{{- if eq (include "aap-config.manifestCsiEnabled" $) "true" }}
  - name: aap-manifest-csi
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: {{ $.Values.aapManifest.csi.secretProviderClassName | quote }}
{{- end }}
initContainers:
  - name: agof-init
    image: {{ .Values.configJob.image }}
    imagePullPolicy: {{ $.Values.configJob.imagePullPolicy }}
    env:
      - name: HOME
        value: /pattern-home
    workingDir: /pattern-home
    command:
      - /bin/bash
      - -c
      - |
          set -euo pipefail
          export GIT_TERMINAL_PROMPT=0
          agof_repo_url={{ $.Values.agof.agof_repo | quote }}
          iac_repo_url={{ $.Values.agof.iac_repo | quote }}
{{- if $.Values.agof.vaultFileKey }}
          base64 -d /pattern-home/agof-vault-file/agof-vault-file > ~/agof_vault.yml
{{- else }}
          printf '%s\n' '{}' > ~/agof_vault.yml
{{- end }}
{{- if eq (include "aap-config.manifestCsiEnabled" $) "true" }}
          CSI={{ $.Values.aapManifest.csi.mountPath | quote }}
          OBJ={{ $.Values.aapManifest.csi.objectName | quote }}
          if [[ -f "$CSI/$OBJ" ]]; then
            base64 -d "$CSI/$OBJ" > /pattern-home/aap-manifest.decoded
          else
            echo "AAP manifest CSI file missing: $CSI/$OBJ" >&2
            exit 1
          fi
{{- end }}
{{- if $.Values.agof.gitAuthSecret }}
          GIT_AUTH_DIR=/pattern-home/git-auth
          if [[ -f "$GIT_AUTH_DIR/.git-credentials" ]]; then
            cp "$GIT_AUTH_DIR/.git-credentials" ~/.git-credentials
            chmod 600 ~/.git-credentials
            git config --global credential.helper store
          elif [[ -f "$GIT_AUTH_DIR/ssh-privatekey" ]]; then
            mkdir -p ~/.ssh
            cp "$GIT_AUTH_DIR/ssh-privatekey" ~/.ssh/id_rsa
            chmod 600 ~/.ssh/id_rsa
            if [[ -f "$GIT_AUTH_DIR/known_hosts" ]]; then
              cp "$GIT_AUTH_DIR/known_hosts" ~/.ssh/known_hosts
              chmod 644 ~/.ssh/known_hosts
              export GIT_SSH_COMMAND='ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes'
            else
              export GIT_SSH_COMMAND='ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new'
            fi
          else
            agof_git_host_from_url() {
              local u="$1"
              if [[ "$u" =~ ^https?://([^/@]+) ]]; then
                echo "${BASH_REMATCH[1]}"
              elif [[ "$u" =~ ^https?://[^@]+@([^/]+) ]]; then
                echo "${BASH_REMATCH[1]}"
              elif [[ "$u" =~ ^git@([^:]+): ]]; then
                echo "${BASH_REMATCH[1]}"
              elif [[ "$u" =~ ^ssh://[^@]+@([^/:]+) ]]; then
                echo "${BASH_REMATCH[1]}"
              fi
            }
            agof_unique_git_hosts() {
              local url h
              for url in "$@"; do
                [[ -z "$url" ]] && continue
                h=$(agof_git_host_from_url "$url") || true
                [[ -n "$h" ]] && printf '%s\n' "$h"
              done | awk '!x[$0]++'
            }
            agof_https_store_credential() {
              local host="$1" user="$2" pass="$3"
              git config --global credential.helper store
              printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' "$host" "$user" "$pass" | git credential approve
            }
            agof_https_user_for_style() {
              local host_lc style
              host_lc=$(echo "$1" | tr '[:upper:]' '[:lower:]')
              style="$2"
              case "$style" in
                github) printf '%s' 'git' ;;
                gitlab) printf '%s' 'oauth2' ;;
                gitea) printf '%s' 'oauth2' ;;
                auto)
                  if [[ "$host_lc" == *"github.com"* ]]; then printf '%s' 'git'
                  elif [[ "$host_lc" == *"gitlab"* ]]; then printf '%s' 'oauth2'
                  elif [[ "$host_lc" == *"gitea"* ]] || [[ "$host_lc" == *"forgejo"* ]] || [[ "$host_lc" == *"codeberg"* ]]; then printf '%s' 'oauth2'
                  else printf '%s' 'git'
                  fi
                  ;;
                *) printf '%s' 'git' ;;
              esac
            }
            https_style={{ default "auto" $.Values.agof.gitAuthHttpsStyle | quote }}
            if [[ -f "$GIT_AUTH_DIR/username" ]] && { [[ -f "$GIT_AUTH_DIR/password" ]] || [[ -f "$GIT_AUTH_DIR/token" ]]; }; then
              u=$(cat "$GIT_AUTH_DIR/username")
              if [[ -f "$GIT_AUTH_DIR/token" ]]; then
                p=$(cat "$GIT_AUTH_DIR/token")
              else
                p=$(cat "$GIT_AUTH_DIR/password")
              fi
              host_any=""
              while IFS= read -r host; do
                [[ -z "$host" ]] && continue
                host_any=1
                agof_https_store_credential "$host" "$u" "$p"
              done < <(agof_unique_git_hosts "$agof_repo_url" "$iac_repo_url")
              if [[ -z "$host_any" ]]; then
                echo "agof.gitAuthSecret: could not parse git host from agof_repo or iac_repo for HTTPS credentials" >&2
                exit 1
              fi
            elif [[ -f "$GIT_AUTH_DIR/token" ]] && [[ ! -f "$GIT_AUTH_DIR/username" ]]; then
              p=$(cat "$GIT_AUTH_DIR/token")
              host_any=""
              while IFS= read -r host; do
                [[ -z "$host" ]] && continue
                host_any=1
                u="$(agof_https_user_for_style "$host" "$https_style")"
                agof_https_store_credential "$host" "$u" "$p"
              done < <(agof_unique_git_hosts "$agof_repo_url" "$iac_repo_url")
              if [[ -z "$host_any" ]]; then
                echo "agof.gitAuthSecret: could not parse git host from agof_repo or iac_repo for HTTPS token" >&2
                exit 1
              fi
            fi
          fi
{{- end }}
          git clone --recurse-submodules --single-branch --branch "{{ $.Values.agof.agof_revision }}" \
            -- "$agof_repo_url" /pattern-home/agof_repo
    volumeMounts:
      - name: agof-scratch-space
        mountPath: /pattern-home
{{- if $.Values.agof.vaultFileKey }}
      - name: agof-vault-file
        mountPath: /pattern-home/agof-vault-file
{{- end }}
{{- if $.Values.agof.gitAuthSecret }}
      - name: agof-git-auth
        mountPath: /pattern-home/git-auth
        readOnly: true
{{- end }}
{{- if eq (include "aap-config.manifestCsiEnabled" $) "true" }}
      - name: aap-manifest-csi
        mountPath: {{ $.Values.aapManifest.csi.mountPath | quote }}
        readOnly: true
{{- end }}
containers:
  - name: agof-config
    image: {{ .Values.configJob.image }}
    imagePullPolicy: {{ $.Values.configJob.imagePullPolicy }}
    env:
      - name: HOME
        value: /pattern-home
      - name: EXTRA_PLAYBOOK_OPTS
        value: {{ .Values.agof.extraPlaybookOpts | quote }}
    workingDir: /pattern-home/agof_repo
    command:
      - timeout
      - {{ .Values.configJob.configTimeout | quote }}
      - make
      - openshift_vp_install
    volumeMounts:
      - name: agof-scratch-space
        mountPath: /pattern-home
{{- if $.Values.agof.vaultFileKey }}
      - name: agof-vault-file
        mountPath: /pattern-home/agof-vault-file
{{- end }}
{{- if eq (include "aap-config.manifestCsiEnabled" $) "true" }}
      - name: aap-manifest-csi
        mountPath: {{ $.Values.aapManifest.csi.mountPath | quote }}
        readOnly: true
{{- end }}
{{- end }} {{/* aap-config.app.configjobspec */}}
