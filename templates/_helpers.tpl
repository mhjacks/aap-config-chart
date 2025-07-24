{{- define "aap-config.app.configjobspec" -}}
metadata:
  name: aap-config-job
spec:
  serviceAccountName: {{ $.Values.serviceAccountName }}
  restartPolicy: Never
  volumes:
    - name: agof-scratch-space
      emptyDir:
        sizeLimit: 5Gi
    - name: agof-vault-file
      secret:
        secretName: agof-vault-file
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
{{- end }} {{/* aap-config.app.configjobspec */}}
