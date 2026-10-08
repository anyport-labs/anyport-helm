{{/*
Release-scoped names. The console names the Helm release after the PluginInstance, so the release
name IS the service name the user sees — the object names equal it rather than appending a chart
suffix. The connection secret's HOST is built from this in domain/plugins/speaches.go, and the two
must agree. fullnameOverride is honoured so the console can pin the name explicitly; it is the
same name either way.
*/}}
{{- define "anyport-speaches.fullname" -}}
{{- .Values.fullnameOverride | default .Release.Name | trunc 52 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-speaches.headlessName" -}}
{{- printf "%s-headless" (include "anyport-speaches.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-speaches.labels" -}}
app.kubernetes.io/name: anyport-speaches
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
anyport.dev/managed: "true"
{{- range $k, $v := .Values.extraLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "anyport-speaches.selectorLabels" -}}
app.kubernetes.io/name: anyport-speaches
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
The image tag: the Speaches release plus the build flavour. Upstream publishes every release as
`<version>-cpu` and `<version>-cuda`, so the GPU switch picks the flavour rather than a second
tag value that could disagree with it.
*/}}
{{- define "anyport-speaches.image" -}}
{{- printf "%s:%s-%s" .Values.image.repository .Values.image.tag (ternary "cuda" "cpu" .Values.gpu.enabled) -}}
{{- end -}}

{{/*
Fail fast when the platform did not point the chart at a credentials secret. Without API_KEY the
server answers every request unauthenticated, so this turns an open service into a rendering
error that names the cause.
*/}}
{{- define "anyport-speaches.authSecret" -}}
{{- if not .Values.auth.existingSecret -}}
{{- fail "auth.existingSecret is required: anyport-speaches does not generate credentials (the platform writes speaches-auth-<instance> before provisioning)" -}}
{{- end -}}
{{- .Values.auth.existingSecret -}}
{{- end -}}
