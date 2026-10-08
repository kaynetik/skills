# Dashboards as code

## Contents

- [File provisioning](#file-provisioning)
- [Kubernetes sidecar](#kubernetes-sidecar)
- [Terraform](#terraform)
- [HTTP API](#http-api)
- [Generators](#generators)
- [Export and review workflow](#export-and-review-workflow)

## File provisioning

`/etc/grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: platform
    orgId: 1
    type: file
    folder: Platform
    folderUid: platform
    disableDeletion: true
    allowUiUpdates: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards/platform
      foldersFromFilesStructure: false
```

- `allowUiUpdates: false` makes the UI refuse saves for production, which keeps Git authoritative. Use `true` only on a scratch instance while authoring, then export the JSON back to Git.
- `disableDeletion: true` stops Grafana removing a dashboard if its file disappears from disk.
- With `foldersFromFilesStructure: true`, subdirectories become folders and `folder` / `folderUid` are ignored. Pick one approach per provider.
- Files hold the dashboard object itself (no `{"dashboard": ...}` wrapper) with a fixed `uid`.
- Provisioned datasources go in `provisioning/datasources/` with a fixed `uid`, so dashboards can reference stable values (or resolve through the `$datasource` variable).

## Kubernetes sidecar

The Grafana Helm chart and kube-prometheus-stack run a sidecar that watches ConfigMaps (or Secrets) and writes them to Grafana's dashboard directory.

```yaml
# values.yaml (grafana chart)
sidecar:
  dashboards:
    enabled: true
    label: grafana_dashboard
    labelValue: "1"
    searchNamespace: ALL
    folderAnnotation: grafana_folder
    provider:
      foldersFromFilesStructure: true
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-monitoring-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
  annotations:
    grafana_folder: Platform
data:
  api-monitoring.json: |
    { "uid": "api-monitoring", "title": "API Monitoring", "panels": [] }
```

- ConfigMaps are limited to about 1 MiB. Split very large dashboards, or generate them smaller with a library.
- Generate ConfigMaps from JSON files instead of pasting JSON into YAML: Kustomize `configMapGenerator` with `files:` and `generatorOptions.labels`, or a Helm `.Files.Glob` template. Use `disableNameSuffixHash: true` in Kustomize if the sidecar must see a stable name.
- Helm templates and Grafana both use `{{ }}`; in Helm-templated dashboards, wrap legend formats like `{{service}}` with a raw string, for example `{{ "{{service}}" }}`, or keep dashboards in files loaded with `.Files.Get` and no templating.
- With Argo CD, point an Application at the directory of ConfigMaps; Grafana picks up changes without restart.

## Terraform

```hcl
terraform {
  required_providers {
    grafana = {
      source = "grafana/grafana"
    }
  }
}

resource "grafana_folder" "platform" {
  title = "Platform"
  uid   = "platform"
}

resource "grafana_dashboard" "api_monitoring" {
  folder      = grafana_folder.platform.uid
  overwrite   = true
  config_json = file("${path.module}/dashboards/api-monitoring.json")
}
```

- Provider version differences exist around `folder` (id vs uid); pin the provider version and check its docs for the argument your version expects.
- Use `templatefile()` to inject environment-specific values (datasource UID, thresholds) rather than forking JSON per environment.
- Alert rules: `grafana_rule_group`; contact points and policies: `grafana_contact_point`, `grafana_notification_policy`. Keep them next to the dashboards they relate to.
- Provide credentials with a service account token via environment (`GRAFANA_AUTH`) or secret manager; never in `.tf` files.

## HTTP API

```bash
jq -n --slurpfile d dashboards/api-monitoring.json \
  '{dashboard: $d[0], folderUid: "platform", overwrite: true, message: "sync from git"}' |
curl -sS -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Bearer $GRAFANA_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary @-
```

Use a service account token scoped to the target folder, not an admin API key. Set `dashboard.id` to `null` so the `uid` is the identity.

## Generators

Hand-maintaining JSON beyond a few dashboards leads to copy-paste drift. Generate it instead:

| Tool | Language | Notes |
| --- | --- | --- |
| Grafana Foundation SDK | Go, TypeScript, Python, Java, PHP | Typed builders emit dashboard JSON; refactor shared panels as functions |
| grafonnet | Jsonnet | Long-standing in the Prometheus/Kubernetes mixin ecosystem; `jb` manages dependencies |

Pattern: one function per panel type (`errorRatioStat(service)`, `latencyPanel(service)`), one dashboard per service built from the same functions, CI emits JSON into the provisioning path, and a diff check fails the build if committed output is stale.

## Export and review workflow

1. Author on a scratch instance with `allowUiUpdates: true`.
2. Export with **Export > Export as JSON**, leaving "Export for sharing externally" off, so datasource references stay as `${datasource}` variable references instead of `${DS_*}` inputs.
3. Normalize before committing: sort keys, set `id: null`, fixed `uid`, stable `version` handling (drop `version`), and remove volatile fields like `iteration`. `jq -S 'del(.id, .version)'` is a reasonable baseline.
4. Review the diff (panel queries, units, thresholds), then merge; the pipeline provisions to Grafana.
5. After deploy, check for UI "unsaved changes" or provisioning errors in Grafana's logs (`logger=provisioning.dashboard`).
