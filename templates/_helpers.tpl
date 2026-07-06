{{- define "aap-config.agof.defaultCacRepo" -}}
{{- "https://github.com/validatedpatterns-demos/ansible-edge-gitops-hmi-config-as-code.git" -}}
{{- end -}}

{{- define "aap-config.agof.defaultCacRevision" -}}
{{- "v2" -}}
{{- end -}}

{{- define "aap-config.agof.configRepo" -}}
{{- $cac := .Values.agof.cac_repo -}}
{{- $iac := .Values.agof.iac_repo -}}
{{- $default := include "aap-config.agof.defaultCacRepo" . -}}
{{- if and $cac (ne $cac $default) -}}
{{- $cac -}}
{{- else if $iac -}}
{{- $iac -}}
{{- else -}}
{{- $cac -}}
{{- end -}}
{{- end -}}

{{- define "aap-config.agof.configRevision" -}}
{{- $cac := .Values.agof.cac_revision -}}
{{- $iac := .Values.agof.iac_revision -}}
{{- $default := include "aap-config.agof.defaultCacRevision" . -}}
{{- if and $cac (ne $cac $default) -}}
{{- $cac -}}
{{- else if $iac -}}
{{- $iac -}}
{{- else -}}
{{- $cac -}}
{{- end -}}
{{- end -}}

{{- define "aap-config.app.configjobspec" -}}
restartPolicy: Never
serviceAccountName: {{ $.Values.serviceAccountName }}
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
          config_repo_url={{ include "aap-config.agof.configRepo" $ | quote }}
{{- if $.Values.agof.vaultFileKey }}
          base64 -d /pattern-home/agof-vault-file/agof-vault-file > ~/agof_vault.yml
{{- else }}
          printf '%s\n' '{}' > ~/agof_vault.yml
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
              done < <(agof_unique_git_hosts "$agof_repo_url" "$config_repo_url")
              if [[ -z "$host_any" ]]; then
                echo "agof.gitAuthSecret: could not parse git host from agof_repo or config repo URL for HTTPS credentials" >&2
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
              done < <(agof_unique_git_hosts "$agof_repo_url" "$config_repo_url")
              if [[ -z "$host_any" ]]; then
                echo "agof.gitAuthSecret: could not parse git host from agof_repo or config repo URL for HTTPS token" >&2
                exit 1
              fi
            fi
          fi
{{- end }}
{{- if $.Values.agof.gitHttpsSslVerify | default true }}
          git clone --recurse-submodules --single-branch --branch "{{ $.Values.agof.agof_revision }}" \
            -- "$agof_repo_url" /pattern-home/agof_repo
{{- else }}
          git -c http.sslVerify=false clone --recurse-submodules --single-branch --branch "{{ $.Values.agof.agof_revision }}" \
            -- "$agof_repo_url" /pattern-home/agof_repo
{{- end }}
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
{{- end }} {{/* aap-config.app.configjobspec */}}
