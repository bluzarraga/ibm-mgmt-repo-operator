{{/*
Check if arch is set and if not "guess" tag to add based on kube platform
*/}}
{{- define "mgmtrepo.platform" -}}
{{- if not .Values.arch }}
  {{- if (eq "linux/amd64" .Capabilities.KubeVersion.Platform) }}
    {{- printf "-%s" "amd64" }}
  {{- end -}}
  {{- if (eq "linux/ppc64le" .Capabilities.KubeVersion.Platform) }}
    {{- printf "-%s" "ppc64le" }}
  {{- end -}}
  {{- if (eq "linux/s390x" .Capabilities.KubeVersion.Platform) }}
    {{- printf "-%s" "s390x" }}
  {{- end -}}
{{- else -}}
  {{- if eq .Values.arch "amd64" }}
    {{- printf "-%s" "amd64" }}
  {{- else -}}
    {{- printf "-%s" .Values.arch }}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return arch based on kube platform
*/}}
{{- define "mgmtrepo.arch" -}}
  {{- if (eq "linux/amd64" .Capabilities.KubeVersion.Platform) }}
    {{- printf "%s" "amd64" }}
  {{- end -}}
  {{- if (eq "linux/ppc64le" .Capabilities.KubeVersion.Platform) }}
    {{- printf "%s" "ppc64le" }}
  {{- end -}}
  {{- if (eq "linux/s390x" .Capabilities.KubeVersion.Platform) }}
    {{- printf "%s" "s390x" }}
  {{- end -}}
{{- end -}}