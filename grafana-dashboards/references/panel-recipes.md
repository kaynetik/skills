# Panel recipes

Classic dashboard JSON for Grafana 10 to 12 with a Prometheus datasource. Every panel references the `$datasource` variable; define it once (see [Variables](#variables)).

## Contents

- [Variables](#variables)
- [Row](#row)
- [Stat](#stat)
- [Time series](#time-series)
- [Table](#table)
- [Heatmap](#heatmap)
- [PromQL patterns](#promql-patterns)
- [SLO panels](#slo-panels)
- [Data links](#data-links)

## Variables

```json
{
  "templating": {
    "list": [
      {
        "name": "datasource",
        "label": "Data source",
        "type": "datasource",
        "query": "prometheus",
        "current": {},
        "hide": 0
      },
      {
        "name": "namespace",
        "label": "Namespace",
        "type": "query",
        "datasource": { "type": "prometheus", "uid": "${datasource}" },
        "definition": "label_values(http_requests_total, namespace)",
        "query": {
          "query": "label_values(http_requests_total, namespace)",
          "refId": "namespace"
        },
        "refresh": 1,
        "sort": 1,
        "multi": false,
        "includeAll": false
      },
      {
        "name": "service",
        "label": "Service",
        "type": "query",
        "datasource": { "type": "prometheus", "uid": "${datasource}" },
        "definition": "label_values(http_requests_total{namespace=\"$namespace\"}, service)",
        "query": {
          "query": "label_values(http_requests_total{namespace=\"$namespace\"}, service)",
          "refId": "service"
        },
        "refresh": 1,
        "sort": 1,
        "multi": true,
        "includeAll": true,
        "allValue": ".*"
      }
    ]
  }
}
```

- `refresh: 1` reloads on dashboard load; `2` reloads on time range change (use only for variables whose values depend on time).
- `allValue: ".*"` keeps queries short when "All" is selected; without it Grafana expands every value into the regex.
- Use in queries: `{namespace="$namespace", service=~"$service"}`.

Useful built-ins: `$__rate_interval` (rate windows), `$__interval` (step-based aggregation), `$__range` (selected range, for `increase(...[$__range])`).

## Row

```json
{
  "type": "row",
  "title": "Latency",
  "collapsed": false,
  "gridPos": { "x": 0, "y": 8, "w": 24, "h": 1 },
  "panels": []
}
```

For a collapsed row, set `collapsed: true` and nest its panels in `panels`; for an expanded row, panels follow the row in the top-level array.

## Stat

Error ratio with background color and sparkline:

```json
{
  "type": "stat",
  "title": "Error ratio (5xx)",
  "description": "Share of requests returning 5xx. Red above 5%. Runbook: https://runbooks.example.com/api-errors",
  "datasource": { "type": "prometheus", "uid": "${datasource}" },
  "targets": [
    {
      "refId": "A",
      "editorMode": "code",
      "expr": "(sum(rate(http_requests_total{namespace=\"$namespace\", service=~\"$service\", status=~\"5..\"}[$__rate_interval])) or vector(0)) / sum(rate(http_requests_total{namespace=\"$namespace\", service=~\"$service\"}[$__rate_interval]))",
      "instant": false
    }
  ],
  "options": {
    "reduceOptions": { "values": false, "calcs": ["lastNotNull"], "fields": "" },
    "orientation": "auto",
    "textMode": "value",
    "colorMode": "background",
    "graphMode": "area",
    "justifyMode": "auto"
  },
  "fieldConfig": {
    "defaults": {
      "unit": "percentunit",
      "decimals": 2,
      "min": 0,
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "color": "green", "value": null },
          { "color": "yellow", "value": 0.01 },
          { "color": "red", "value": 0.05 }
        ]
      }
    },
    "overrides": []
  },
  "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 }
}
```

The first threshold step must have `value: null` (the base). Thresholds are in the field's unit: `percentunit` uses 0 to 1, `percent` uses 0 to 100.

## Time series

Request rate by service (replaces legacy `graph`):

```json
{
  "type": "timeseries",
  "title": "Request rate",
  "description": "Requests per second by service.",
  "datasource": { "type": "prometheus", "uid": "${datasource}" },
  "targets": [
    {
      "refId": "A",
      "editorMode": "code",
      "expr": "sum by (service) (rate(http_requests_total{namespace=\"$namespace\", service=~\"$service\"}[$__rate_interval]))",
      "legendFormat": "{{service}}",
      "range": true
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "reqps",
      "min": 0,
      "custom": {
        "drawStyle": "line",
        "lineInterpolation": "linear",
        "lineWidth": 1,
        "fillOpacity": 10,
        "showPoints": "never",
        "spanNulls": false,
        "stacking": { "mode": "none", "group": "A" }
      }
    },
    "overrides": []
  },
  "options": {
    "legend": { "displayMode": "table", "placement": "bottom", "calcs": ["mean", "max"] },
    "tooltip": { "mode": "multi", "sort": "desc" }
  },
  "gridPos": { "x": 0, "y": 4, "w": 12, "h": 8 }
}
```

Latency percentiles (three targets, one panel):

```json
{
  "type": "timeseries",
  "title": "Latency p50 / p95 / p99",
  "datasource": { "type": "prometheus", "uid": "${datasource}" },
  "targets": [
    {
      "refId": "A",
      "expr": "histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"$namespace\", service=~\"$service\"}[$__rate_interval])))",
      "legendFormat": "p50"
    },
    {
      "refId": "B",
      "expr": "histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"$namespace\", service=~\"$service\"}[$__rate_interval])))",
      "legendFormat": "p95"
    },
    {
      "refId": "C",
      "expr": "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"$namespace\", service=~\"$service\"}[$__rate_interval])))",
      "legendFormat": "p99"
    }
  ],
  "fieldConfig": {
    "defaults": { "unit": "s", "min": 0, "custom": { "fillOpacity": 0, "showPoints": "never" } },
    "overrides": []
  },
  "options": {
    "legend": { "displayMode": "list", "placement": "bottom" },
    "tooltip": { "mode": "multi", "sort": "desc" }
  },
  "gridPos": { "x": 12, "y": 4, "w": 12, "h": 8 }
}
```

Draw an SLO or alert threshold as a line:

```json
"fieldConfig": {
  "defaults": {
    "custom": {
      "thresholdsStyle": { "mode": "line" }
    },
    "thresholds": {
      "mode": "absolute",
      "steps": [
        { "color": "green", "value": null },
        { "color": "red", "value": 0.5 }
      ]
    }
  }
}
```

CPU utilization per node (USE):

```promql
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval]))
```

Set `unit: "percentunit"`, `min: 0`, `max: 1`.

## Table

Service status from `up`, with value mapping and organized columns:

```json
{
  "type": "table",
  "title": "Scrape targets",
  "datasource": { "type": "prometheus", "uid": "${datasource}" },
  "targets": [
    {
      "refId": "A",
      "expr": "up{namespace=\"$namespace\"}",
      "format": "table",
      "instant": true
    }
  ],
  "transformations": [
    {
      "id": "organize",
      "options": {
        "excludeByName": { "Time": true, "__name__": true },
        "renameByName": { "instance": "Instance", "job": "Service", "Value": "Status" }
      }
    }
  ],
  "fieldConfig": {
    "defaults": {
      "custom": { "cellOptions": { "type": "color-background" } },
      "mappings": [
        {
          "type": "value",
          "options": {
            "0": { "text": "DOWN", "color": "red", "index": 0 },
            "1": { "text": "UP", "color": "green", "index": 1 }
          }
        }
      ]
    },
    "overrides": [
      {
        "matcher": { "id": "byName", "options": "Status" },
        "properties": [{ "id": "custom.width", "value": 100 }]
      }
    ]
  },
  "options": { "showHeader": true, "sortBy": [{ "displayName": "Status", "desc": false }] },
  "gridPos": { "x": 0, "y": 12, "w": 12, "h": 8 }
}
```

Always set `instant: true` and `format: "table"` for tables; range queries produce one row per sample.

## Heatmap

Latency distribution from classic histogram buckets:

```json
{
  "type": "heatmap",
  "title": "Latency distribution",
  "datasource": { "type": "prometheus", "uid": "${datasource}" },
  "targets": [
    {
      "refId": "A",
      "expr": "sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"$namespace\", service=~\"$service\"}[$__rate_interval]))",
      "format": "heatmap",
      "legendFormat": "{{le}}",
      "range": true
    }
  ],
  "options": {
    "calculate": false,
    "yAxis": { "axisPlacement": "left", "unit": "s" },
    "color": { "mode": "scheme", "scheme": "Spectral", "scale": "exponential", "steps": 64 },
    "cellGap": 1,
    "tooltip": { "mode": "single", "yHistogram": false },
    "legend": { "show": true }
  },
  "gridPos": { "x": 12, "y": 12, "w": 12, "h": 8 }
}
```

The legacy `dataFormat: "tsbuckets"` and top-level `yAxis` keys belong to the pre-Grafana-9 heatmap and are ignored by the current panel. Keep the unit on the options `yAxis`; the bucket `le` must be seconds to match `unit: "s"`.

## PromQL patterns

| Intent | Query |
| --- | --- |
| Request rate | `sum by (service) (rate(http_requests_total[$__rate_interval]))` |
| Error ratio | `(sum(rate(http_requests_total{status=~"5.."}[$__rate_interval])) or vector(0)) / sum(rate(http_requests_total[$__rate_interval]))` |
| Error ratio per service | `sum by (service) (rate(http_requests_total{status=~"5.."}[$__rate_interval])) / sum by (service) (rate(http_requests_total[$__rate_interval]))` |
| p95 latency | `histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket[$__rate_interval])))` |
| Average latency | `sum(rate(http_request_duration_seconds_sum[$__rate_interval])) / sum(rate(http_request_duration_seconds_count[$__rate_interval]))` |
| Memory used % | `1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes` |
| Saturation: load per core | `node_load1 / count without (cpu, mode) (node_cpu_seconds_total{mode="idle"})` |
| Pod restarts in range | `sum by (pod) (increase(kube_pod_container_status_restarts_total[$__range]))` |
| Cache hit ratio | `sum(rate(cache_hits_total[$__rate_interval])) / (sum(rate(cache_hits_total[$__rate_interval])) + sum(rate(cache_misses_total[$__rate_interval])))` |
| Connection pool in use | `db_pool_connections_in_use / db_pool_connections_max` |

Metric names vary by exporter and instrumentation library; confirm with the Explore view or `label_values` before committing a query. If a division can have a zero denominator, the panel shows "No data" at idle; decide whether that is correct for the audience.

## SLO panels

Use recording rules so dashboards read pre-aggregated series instead of scanning 30 days of raw data:

```yaml
groups:
  - name: sli_api
    rules:
      - record: sli:http_error_ratio:rate5m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))
      - record: sli:http_error_ratio:rate1h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1h]))
          /
          sum(rate(http_requests_total[1h]))
```

Panels (target SLO 99.9 percent, error budget 0.001):

| Panel | Query | Unit |
| --- | --- | --- |
| Availability, 30d | `1 - (sum(increase(http_requests_total{status=~"5.."}[30d])) / sum(increase(http_requests_total[30d])))` | `percentunit` |
| Error budget remaining | `1 - (sum(increase(http_requests_total{status=~"5.."}[30d])) / sum(increase(http_requests_total[30d]))) / 0.001` | `percentunit` |
| Burn rate, 1h | `sli:http_error_ratio:rate1h / 0.001` | `none` |
| Burn rate, 5m | `sli:http_error_ratio:rate5m / 0.001` | `none` |

- A burn rate of 1 consumes exactly the budget over the SLO window; a sustained 14.4 over one hour (with a 5m confirmation window) is a common fast-burn page threshold. Put the matching thresholds on the stat panels and define the pages in alert rules, not in the dashboard.
- Error budget remaining can go negative; set `min` to a negative value or leave unset so the overrun is visible.
- Prefer a single source of truth for the SLO target (a variable or recording rule) instead of repeating `0.001` in many queries.

## Data links

Drill from an overview panel into a detail dashboard while preserving context:

```json
"fieldConfig": {
  "defaults": {
    "links": [
      {
        "title": "Service detail",
        "url": "/d/service-detail/service-detail?var-namespace=${namespace}&var-service=${__field.labels.service}&${__url_time_range}"
      }
    ]
  }
}
```
