---
name: grafana-dashboards
description: Designs and reviews production Grafana dashboards for Prometheus-style metrics -- layout and information hierarchy, RED/USE/SLO methods, modern panel JSON (timeseries, stat, table, heatmap), template variables, thresholds and units, unified alerting boundaries, and dashboards-as-code (file provisioning, Kubernetes sidecar, Terraform, Grafana Foundation SDK/Jsonnet). Use when building or refactoring Grafana dashboards, writing dashboard JSON, choosing panel types, wiring variables, provisioning dashboards via Git, or when the user mentions Grafana, dashboard JSON, panels, PromQL visualization, SLO dashboard, or dashboards.yml.
---

# Grafana Dashboards

Build dashboards that answer a specific operational question quickly, and ship them as reviewed code. The JSON in this skill targets the classic dashboard model (Grafana 10 to 12). Grafana 12 can also export a newer v2 schema behind feature toggles; do not mix v2 exports with the snippets here.

## Workflow

```text
Task Progress:
- [ ] 1. Define audience and the question the dashboard answers
- [ ] 2. Pick the method: RED (services), USE (resources), SLO (reliability)
- [ ] 3. Sketch the layout top-down (see hierarchy below)
- [ ] 4. Define variables first, then write panels against them
- [ ] 5. Set units, thresholds, descriptions, and links
- [ ] 6. Store as code with a stable uid and provision it
- [ ] 7. Verify: JSON valid, queries return data, works at 1h / 6h / 7d
```

## Design principles

### Information hierarchy

```text
Row 1  Status at a glance   stat / gauge panels: current error ratio, p95, saturation, SLO budget
Row 2  Trends               timeseries panels: rate, errors, latency over the selected range
Row 3  Breakdown            tables, heatmaps, per-instance or per-route detail
```

- One dashboard answers one question for one audience. Split overview from deep-dive and link them with dashboard links and data links carrying `var-*` and time range.
- Put the answer to "is it healthy?" in the top row, readable in under five seconds.
- Keep panel count low (roughly 12 to 20). Collapse rarely-needed detail into collapsed rows; panels in collapsed rows do not query until expanded.
- Alert on symptoms elsewhere (alert rules); dashboards are for triage and diagnosis.

### RED (request-driven services)

| Signal | Panel | Unit |
| --- | --- | --- |
| Rate | `sum by (service) (rate(http_requests_total[$__rate_interval]))` | `reqps` |
| Errors | 5xx ratio of total | `percentunit` |
| Duration | p50/p95/p99 via `histogram_quantile` | `s` |

### USE (resources: CPU, memory, disk, network, pools)

| Signal | Meaning | Example |
| --- | --- | --- |
| Utilization | Fraction of time or capacity busy | CPU busy %, pool in-use / max |
| Saturation | Queued or waiting work | run queue, pending requests, pool wait time |
| Errors | Error events on the resource | NIC drops, disk errors, OOM kills |

### SLO

Show SLI over a window, error budget remaining, and multi-window burn rate. Use recording rules for anything over long ranges; see [references/panel-recipes.md](references/panel-recipes.md#slo-panels).

## Dashboard skeleton

```json
{
  "uid": "api-monitoring",
  "title": "API Monitoring",
  "tags": ["api", "production"],
  "timezone": "browser",
  "refresh": "30s",
  "time": { "from": "now-6h", "to": "now" },
  "graphTooltip": 1,
  "schemaVersion": 39,
  "templating": { "list": [] },
  "annotations": { "list": [] },
  "links": [],
  "panels": []
}
```

- Set a stable, human-readable `uid` (max 40 chars). Provisioning and links key off `uid`, not `id`; keep `id` `null` or omit it.
- `graphTooltip: 1` shares the crosshair across panels, which makes correlating panels much faster.
- File provisioning and Terraform take the dashboard object directly. Only the HTTP API (`POST /api/dashboards/db`) needs the `{"dashboard": {...}, "folderUid": "...", "overwrite": true}` wrapper.
- Panels use a 24-column grid: `gridPos: {x, y, w, h}`. Stat panels are typically `w: 4` to `6`, `h: 4`; timeseries `w: 12`, `h: 8`.

## Panel selection

| Need | Panel | Notes |
| --- | --- | --- |
| Current value vs threshold | `stat` | Use `lastNotNull`, `colorMode: "background"` or `"value"` |
| Value against a max | `gauge` or `bargauge` | Only when a bounded range makes sense |
| Trend over time | `timeseries` | Replaces the legacy `graph` panel |
| Distribution of latency | `heatmap` | Requires `_bucket` series with `format: heatmap` |
| Per-instance or per-route comparison | `table` with `instant: true` | Hide `Time`, rename columns, color cells |
| Discrete states | `state-timeline` or `status-history` | Up/down, deploy phases |
| Narrative or runbook links | `text` | Keep short |

Do not use the legacy `graph`, `singlestat`, or `table-old` panels in new dashboards; Grafana auto-migrates them on load, which makes diffs noisy. Full JSON for each panel is in [references/panel-recipes.md](references/panel-recipes.md).

## Variables

- Define a `datasource` variable first and reference it as `{"type": "prometheus", "uid": "${datasource}"}` in every panel and variable. Never hardcode datasource names or UIDs per panel.
- Source label values from the metric the panels actually query (for example `label_values(http_requests_total{namespace="$namespace"}, service)`), not from an unrelated info metric, so the dropdown only lists series that have data.
- Multi-value variables need regex matchers: `service=~"$service"`. Single-value variables can use `=`. Using `=` with a multi-value variable breaks on selecting two values.
- Use `$__rate_interval` inside `rate()` and `increase()`; do not hardcode `[5m]`. It adapts to scrape interval and zoom level.
- Order variables so parents come before children; chained variables refresh when the parent changes.

## Alerts

Legacy per-panel alerts (the `alert` key on a panel) were removed in Grafana 11. Do not add them. Instead:

- Define Grafana-managed alert rules (provisioned as YAML or Terraform `grafana_rule_group`) or Prometheus/Mimir rule files.
- Alert on user-visible symptoms and SLO burn rate, not on every resource metric.
- Show state on dashboards with an `alertlist` panel, annotations from alert rules, and a link from alert rules back to the dashboard (`__dashboardUid__` and `__panelId__` annotations).

## Dashboards as code

Dashboards edited in the UI drift. Treat the JSON (or the generator that emits it) in Git as the source of truth, and disable UI edits for provisioned production dashboards.

| Method | Use when |
| --- | --- |
| File provisioning (`dashboards.yml`) | Single Grafana, config-managed host or container |
| Kubernetes sidecar + labeled ConfigMaps | Grafana Helm chart / kube-prometheus-stack, GitOps with Argo CD or Flux |
| Terraform `grafana_dashboard` | Grafana Cloud or multiple instances, folders and permissions in IaC |
| Grafana Foundation SDK or grafonnet (Jsonnet) | Many similar dashboards; avoid hand-maintaining large JSON |

Provisioning snippets, Kubernetes ConfigMap layout, and Terraform are in [references/dashboards-as-code.md](references/dashboards-as-code.md). For packaging dashboards in charts, see the `helm`, `kustomize`, and `argocd` skills.

## Best practices

1. Pick units explicitly (`reqps`, `s`, `bytes`, `percentunit`, `percent`); never rely on "short".
2. Set `min`/`max` on percentage and ratio axes so scale changes do not hide regressions.
3. Thresholds: `base` step first with `value: null`, then ascending steps. Use the same green/yellow/red meaning everywhere; do not use red for non-error series.
4. Put a `description` on every non-obvious panel: what the query measures, the threshold's rationale, and the runbook link.
5. Name series with `legendFormat` (`{{service}}`), not raw label sets.
6. Keep queries cheap: aggregate with `sum by (...)`, avoid `{__name__=~".+"}`, and use recording rules for expensive or long-range expressions.
7. Use `or vector(0)` on error numerators so "no errors" renders as 0 rather than "No data".
8. Check at several ranges (1h, 6h, 7d). Rate windows, step, and heatmap bucket density change with range.
9. Default time range `now-6h` for operational dashboards; `now-30d` only for SLO/capacity views.
10. Consistent naming for panels, variables, and tags across dashboards; use tags and folders for discovery.

## Verification

```bash
# Valid JSON, and uid present
jq -e '.uid and (.panels | length > 0)' dashboards/api-monitoring.json

# Find legacy panel types and per-panel alerts that should not be committed
jq -r '.. | objects | select(.type? == "graph" or .type? == "singlestat" or has("alert")) | .title // .type' dashboards/*.json

# Panels with no unit set (review manually)
jq -r '.panels[] | select(.type == "timeseries" or .type == "stat") | select(.fieldConfig.defaults.unit == null) | .title' dashboards/api-monitoring.json
```

## Working through Grafana MCP tools

When a Grafana MCP server is available:

- Discover with `search_dashboards`, then inspect with `get_dashboard_summary`; use `get_dashboard_property` with a JSONPath for a single panel or variable. Avoid `get_dashboard_by_uid` on large dashboards.
- Prefer `patch_dashboard` for targeted edits over `update_dashboard` with a full payload.
- Do not call write operations (`update_dashboard`, alert rule or incident creation) unless the user asks for them. Writing to a provisioned dashboard from the API is overwritten on next sync; change the source in Git instead.
- Return `generate_deeplink` URLs rather than describing click paths.
- Query Prometheus with a bounded time range, and Loki with label matchers, when validating panel queries.

## Anti-patterns

- Dozens of panels on one screen with no hierarchy.
- Hardcoded `[5m]` ranges, datasource names, or namespaces.
- Legacy `graph` panels and panel-level `alert` blocks copied from old dashboards.
- Averages of percentiles; compute quantiles from summed `_bucket` series with `by (le)`.
- `rate()` on a gauge or `avg()` over a counter without `rate()`.
- Editing provisioned dashboards in the UI and never exporting back.
- Exporting "for sharing externally" and committing `${DS_PROMETHEUS}` inputs into provisioned JSON.

## Additional resources

- Panel JSON, variable definitions, PromQL patterns, SLO panels: [references/panel-recipes.md](references/panel-recipes.md)
- Provisioning, Kubernetes sidecar, Terraform, generators: [references/dashboards-as-code.md](references/dashboards-as-code.md)
