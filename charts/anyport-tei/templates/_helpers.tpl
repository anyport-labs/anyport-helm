{{/*
Release-scoped names. The console names the Helm release after the PluginInstance
(HelmProvisioner.Provision uses instance.Name), so the release name IS the service name the
user sees — keep the object names equal to it rather than appending a chart suffix. The
connection secret's HOST is built from this in domain/plugins/tei.go, and the two must agree.
*/}}
{{- define "anyport-tei.fullname" -}}
{{- .Release.Name | trunc 52 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-tei.headlessName" -}}
{{- printf "%s-headless" (include "anyport-tei.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-tei.labels" -}}
app.kubernetes.io/name: anyport-tei
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
anyport.dev/managed: "true"
{{- range $k, $v := .Values.extraLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "anyport-tei.selectorLabels" -}}
app.kubernetes.io/name: anyport-tei
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
The image for the chosen architecture. Hugging Face publishes the CPU build as one
single-architecture tag per platform, so the architecture is part of the tag and an unknown one
is a rendering error rather than an image that does not exist.
*/}}
{{- define "anyport-tei.image" -}}
{{- $v := .Values.image.version | toString -}}
{{- if eq .Values.image.arch "amd64" -}}
{{- printf "%s:cpu-%s" .Values.image.repository $v -}}
{{- else if eq .Values.image.arch "arm64" -}}
{{- printf "%s:cpu-arm64-%s" .Values.image.repository $v -}}
{{- else -}}
{{- fail (printf "image.arch must be amd64 or arm64, got %q" (.Values.image.arch | toString)) -}}
{{- end -}}
{{- end -}}

{{/*
Fail fast when the platform did not point the chart at a credentials secret: without API_KEY the
server answers every request, and this chart never starts it that way.
*/}}
{{- define "anyport-tei.authSecret" -}}
{{- if not .Values.auth.existingSecret -}}
{{- fail "auth.existingSecret is required: anyport-tei does not generate credentials (the platform writes tei-auth-<instance> before provisioning)" -}}
{{- end -}}
{{- .Values.auth.existingSecret -}}
{{- end -}}
