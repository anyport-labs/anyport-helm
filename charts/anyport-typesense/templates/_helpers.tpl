{{/*
Release-scoped names. The console names the Helm release after the PluginInstance, so the release
name IS the service name the user sees — the object names equal it rather than appending a chart
suffix. The connection secret's HOST is built from this in domain/plugins/catalog.go, and the two
must agree. fullnameOverride is honoured so the console can pin the name explicitly; it is the
same name either way.
*/}}
{{- define "anyport-typesense.fullname" -}}
{{- .Values.fullnameOverride | default .Release.Name | trunc 52 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-typesense.headlessName" -}}
{{- printf "%s-headless" (include "anyport-typesense.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-typesense.labels" -}}
app.kubernetes.io/name: anyport-typesense
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
anyport.dev/managed: "true"
{{- range $k, $v := .Values.extraLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "anyport-typesense.selectorLabels" -}}
app.kubernetes.io/name: anyport-typesense
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Fail fast when the platform did not point the chart at a credentials secret. Typesense refuses
to start without an API key, so this turns a crash loop into a rendering error that names the
cause.
*/}}
{{- define "anyport-typesense.authSecret" -}}
{{- if not .Values.auth.existingSecret -}}
{{- fail "auth.existingSecret is required: anyport-typesense does not generate credentials (the platform writes typesense-auth-<instance> before provisioning)" -}}
{{- end -}}
{{- .Values.auth.existingSecret -}}
{{- end -}}
