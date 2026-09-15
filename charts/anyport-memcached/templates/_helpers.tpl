{{/*
Release-scoped names. The console names the Helm release after the PluginInstance, so the release
name IS the service name the user sees — the object names equal it rather than appending a chart
suffix. The connection secret's HOST is built from this in domain/plugins/catalog.go, and the two
must agree.
*/}}
{{- define "anyport-memcached.fullname" -}}
{{- .Release.Name | trunc 52 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-memcached.labels" -}}
app.kubernetes.io/name: anyport-memcached
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
anyport.dev/managed: "true"
{{- range $k, $v := .Values.extraLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "anyport-memcached.selectorLabels" -}}
app.kubernetes.io/name: anyport-memcached
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
