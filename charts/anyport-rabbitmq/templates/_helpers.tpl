{{/*
Release-scoped names. The console names the Helm release after the PluginInstance
(HelmProvisioner.Provision uses instance.Name), so the release name IS the service name the
user sees — keep the object names equal to it rather than appending a chart suffix. The
connection secret's HOST is built from this in domain/plugins/catalog.go, and the two must
agree.
*/}}
{{- define "anyport-rabbitmq.fullname" -}}
{{- .Release.Name | trunc 52 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-rabbitmq.headlessName" -}}
{{- printf "%s-headless" (include "anyport-rabbitmq.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
The management UI's own Service, so publishing the dashboard to a domain cannot accidentally
publish the AMQP port alongside it. Named by ExposeSpec.ServiceNameTmpl in catalog.go.
*/}}
{{- define "anyport-rabbitmq.managementName" -}}
{{- printf "%s-management" (include "anyport-rabbitmq.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "anyport-rabbitmq.labels" -}}
app.kubernetes.io/name: anyport-rabbitmq
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
anyport.dev/managed: "true"
{{- range $k, $v := .Values.extraLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "anyport-rabbitmq.selectorLabels" -}}
app.kubernetes.io/name: anyport-rabbitmq
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Fail fast when the platform did not point the chart at a credentials secret. RabbitMQ would
otherwise fall back to its built-in guest/guest, which is reachable from every pod in the
namespace — worse than not installing.
*/}}
{{- define "anyport-rabbitmq.authSecret" -}}
{{- if not .Values.auth.existingSecret -}}
{{- fail "auth.existingSecret is required: anyport-rabbitmq does not generate credentials (the platform writes rabbitmq-auth-<instance> before provisioning)" -}}
{{- end -}}
{{- .Values.auth.existingSecret -}}
{{- end -}}
