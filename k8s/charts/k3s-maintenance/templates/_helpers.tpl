{{- define "k3s-maintenance.networkHealth.echoServiceName" -}}
{{- default (printf "%s-network-echo" .Release.Name) .Values.networkHealth.echo.serviceName -}}
{{- end -}}

{{- define "k3s-maintenance.networkHealth.echoDaemonSetName" -}}
{{- default (printf "%s-network-echo" .Release.Name) .Values.networkHealth.echo.daemonSetName -}}
{{- end -}}

{{- define "k3s-maintenance.networkHealth.echoAppLabel" -}}
{{- default (printf "%s-network-echo" .Release.Name) .Values.networkHealth.echo.appLabel -}}
{{- end -}}

{{- define "k3s-maintenance.networkHealth.healthCheckCronJobName" -}}
{{- default (printf "%s-network-health-check" .Release.Name) .Values.networkHealth.cronJobs.healthCheckName -}}
{{- end -}}

{{- define "k3s-maintenance.networkHealth.crossNodeCheckerName" -}}
{{- default (printf "%s-network-crossnode-checker" .Release.Name) .Values.networkHealth.rbac.checkerName -}}
{{- end -}}

{{- define "k3s-maintenance.networkHealth.crossNodeCheckCronJobName" -}}
{{- default (printf "%s-network-crossnode-check" .Release.Name) .Values.networkHealth.cronJobs.crossNodeCheckName -}}
{{- end -}}
