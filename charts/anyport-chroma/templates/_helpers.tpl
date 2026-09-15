{{/*
Release-scoped names. The console names the Helm release after the PluginInstance
(HelmProvisioner.Provision uses instance.Name), so the release name IS the service name the
user sees — keep the object names equal to it rather than appending a chart suffix. The
connection secret's HOST is built from this in domain/plugins/chroma.go, and the two must
agree.
*/}}
{{- define "anyport-chroma.fullname" -}}
{{- .Release.Name | trunc 52 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-chroma.headlessName" -}}
{{- printf "%s-headless" (include "anyport-chroma.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-chroma.labels" -}}
app.kubernetes.io/name: anyport-chroma
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
anyport.dev/managed: "true"
{{- range $k, $v := .Values.extraLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "anyport-chroma.selectorLabels" -}}
app.kubernetes.io/name: anyport-chroma
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
