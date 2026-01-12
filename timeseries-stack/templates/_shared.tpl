
{{- define "timeseries.shared.initContainer" -}}
- name: shared-files-init
  image: {{ .Values.shared.files.image }}
  imagePullPolicy: {{ default "IfNotPresent" .Values.images.pullPolicy }}
  command:
    - sh
    - -c
    - >-
      if [ -d /dest ] && [ -z "$(ls -A /dest)" ]; then
        cp -R {{ .Values.shared.files.sourcePath }}/* /dest/ || true;
      else
        echo "Shared volume already populated, skipping.";
      fi
  volumeMounts:
    - name: shared-data
      mountPath: /dest
{{- end -}}

{{- define "timeseries.shared.volumes" -}}
- name: shared-data
  persistentVolumeClaim:
    claimName: {{ .Values.shared.pvc.name }}
{{- end -}}

{{- define "timeseries.shared.volumeMounts" -}}
- name: shared-data
  mountPath: {{ .Values.shared.files.targetPath }}
  readOnly: true
{{- end -}}
