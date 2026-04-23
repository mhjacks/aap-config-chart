{{- define "aap-config.app.configjobspec" -}}
{{- $m := $.Values.aapManifest -}}
{{- if and (ne $m.source "sscsi") (ne $m.source "externalSecret") }}
{{- fail "aapManifest.source must be \"sscsi\" or \"externalSecret\"" }}
{{- end }}
restartPolicy: Never
serviceAccountName: {{ $.Values.serviceAccountName }}
volumes:
  - name: agof-scratch-space
    emptyDir:
      sizeLimit: 5Gi
  - name: agof-vault-file
    secret:
      secretName: agof-vault-file
{{- if eq $m.source "sscsi" }}
  - name: aap-manifest
    csi:
      driver: {{ $m.sscsi.driver | quote }}
      readOnly: true
      volumeAttributes:
        secretProviderClass: {{ required "aapManifest.sscsi.secretProviderClass is required when aapManifest.source is sscsi" $m.sscsi.secretProviderClass | quote }}
{{- else }}
  - name: aap-manifest
    secret:
      secretName: {{ required "aapManifest.externalSecret.secretName is required when aapManifest.source is externalSecret" $m.externalSecret.secretName | quote }}
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
      - >
        base64 -d /pattern-home/agof-vault-file/agof-vault-file > ~/agof_vault.yml &&
        git clone --recurse-submodules --single-branch --branch "{{ .Values.agof.agof_revision }}" 
        -- "{{ .Values.agof.agof_repo }}" /pattern-home/agof_repo
    volumeMounts:
      - name: agof-scratch-space
        mountPath: /pattern-home
      - name: agof-vault-file
        mountPath: /pattern-home/agof-vault-file
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
      - name: agof-vault-file
        mountPath: /pattern-home/agof-vault-file
      - name: aap-manifest
        mountPath: {{ ternary $m.sscsi.mountPath $m.externalSecret.mountPath (eq $m.source "sscsi") | quote }}
        readOnly: true
{{- end }} {{/* aap-config.app.configjobspec */}}
