---
name: argocd
description: ArgoCD GitOps operations -- Application and AppProject authoring, multi-source apps, ApplicationSet generators (Go templates, progressive sync), sync strategies, RBAC, SSO, health checks, CLI commands, and troubleshooting. Use when writing ArgoCD manifests, managing deployments, configuring sync policies, debugging sync/health status, or when the user mentions ArgoCD, GitOps, ApplicationSet, AppProject, argocd CLI, sync wave, or self-heal.
---

# ArgoCD

## Architecture

```text
argocd (namespace)
  api-server                -- UI / CLI / API gateway
  repo-server               -- Git interaction, manifest rendering
  application-controller    -- K8s reconciliation loop
  applicationset-controller -- ApplicationSet reconciliation
  redis                     -- caching
  dex                       -- SSO / OIDC
```

## Application (single source)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: production
  source:
    repoURL: https://github.com/myorg/myapp
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Helm source

```yaml
source:
  repoURL: https://github.com/myorg/helm-charts
  targetRevision: main
  path: charts/myapp
  helm:
    releaseName: myapp
    valueFiles:
    - values.yaml
    - values-production.yaml
    parameters:
    - name: image.tag
      value: "v2.0.0"
```

### Kustomize source

```yaml
source:
  repoURL: https://github.com/myorg/myapp
  targetRevision: main
  path: k8s/overlays/production
  kustomize:
    images:
    - myregistry.io/myapp:v2.0.0
    commonLabels:
      environment: production
```

## Application (multi-source)

Use `spec.sources` (plural) to combine manifests from multiple repositories -- for example, a Helm chart from one repo with environment-specific values from another.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: billing-app
  namespace: argocd
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: billing
  sources:
  - repoURL: https://github.com/myorg/helm-charts
    targetRevision: v3.2.0
    path: charts/billing
    helm:
      valueFiles:
      - $values/envs/production/values.yaml
  - repoURL: https://github.com/myorg/config
    targetRevision: main
    ref: values
```

The `ref: values` entry makes that repo accessible as `$values` in `valueFiles` paths. `spec.sources` replaces `spec.source` -- they are mutually exclusive.

## AppProject

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  sourceRepos:
  - https://github.com/myorg/*
  destinations:
  - namespace: production
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  roles:
  - name: developer
    policies:
    - p, proj:production:developer, applications, sync, production/*, allow
    - p, proj:production:developer, applications, get, production/*, allow
    groups:
    - developers
  syncWindows:
  - kind: allow
    schedule: '0 9 * * 1-5'
    duration: 8h
    applications:
    - '*'
  orphanedResources:
    warn: true
```

## ApplicationSet generators

Enable Go templates with `goTemplate: true` and `goTemplateOptions: ["missingkey=error"]` (recommended). Go template syntax uses `{{.field}}` instead of the legacy `{{field}}` fasttemplate syntax.

### Git (directory per environment)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-envs
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - git:
      repoURL: https://github.com/myorg/myapp
      revision: main
      directories:
      - path: k8s/overlays/*
  template:
    metadata:
      name: 'myapp-{{.path.basename}}'
    spec:
      project: production
      source:
        repoURL: https://github.com/myorg/myapp
        targetRevision: main
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### List (multi-cluster)

```yaml
generators:
- list:
    elements:
    - cluster: us-east-1
      url: https://cluster1.example.com
    - cluster: eu-central-1
      url: https://cluster2.example.com
template:
  metadata:
    name: 'myapp-{{.cluster}}'
  spec:
    destination:
      server: '{{.url}}'
      namespace: production
```

### Matrix (environments x clusters)

```yaml
generators:
- matrix:
    generators:
    - git:
        repoURL: https://github.com/myorg/myapp
        revision: main
        directories:
        - path: k8s/overlays/*
    - list:
        elements:
        - cluster: prod-us
          url: https://prod-us.example.com
        - cluster: prod-eu
          url: https://prod-eu.example.com
```

### Progressive sync (RollingSync)

Stages rollouts across environments. Each step matches applications by label and controls how many can update concurrently.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-rolling
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev.example.com
        env: env-dev
      - cluster: staging
        url: https://staging.example.com
        env: env-staging
      - cluster: prod
        url: https://prod.example.com
        env: env-prod
  strategy:
    type: RollingSync
    rollingSync:
      steps:
      - matchExpressions:
        - key: envLabel
          operator: In
          values: [env-dev]
      - matchExpressions:
        - key: envLabel
          operator: In
          values: [env-staging]
        maxUpdate: 0
      - matchExpressions:
        - key: envLabel
          operator: In
          values: [env-prod]
        maxUpdate: 10%
  template:
    metadata:
      name: 'myapp-{{.cluster}}'
      labels:
        envLabel: '{{.env}}'
    spec:
      project: production
      source:
        repoURL: https://github.com/myorg/myapp
        targetRevision: main
        path: 'k8s/overlays/{{.cluster}}'
      destination:
        server: '{{.url}}'
        namespace: myapp
```

`maxUpdate: 0` means the step requires manual promotion (or an external trigger). `maxUpdate: 10%` limits concurrent updates to 10% of matching apps.

### Ignore application differences

Prevents the ApplicationSet controller from overwriting fields that operators modify manually (e.g., pinning a branch for debugging).

```yaml
spec:
  ignoreApplicationDifferences:
  - jqPathExpressions:
    - .spec.sources[] | select(.repoURL == "https://github.com/myorg/repo").targetRevision
```

Caveat: MergePatch replaces entire lists on any change, so modifying other sources in the same `sources` list can still reset the ignored field.

## Sync hooks and waves

```yaml
# PreSync job -- runs before sync, deleted on success
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    argocd.argoproj.io/sync-wave: "1"

# PostSync smoke test
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: "5"
```

Waves are ordered lowest-first. Resources in the same wave are applied together.

## RBAC (argocd-rbac-cm)

```yaml
data:
  policy.default: role:readonly
  policy.csv: |
    g, myorg:platform-team, role:admin
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, repositories, get, *, allow
  scopes: '[groups, email]'
```

## SSO (Dex + GitHub)

```yaml
# argocd-cm
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
    - type: github
      id: github
      name: GitHub
      config:
        clientID: $dex.github.clientId
        clientSecret: $dex.github.clientSecret
        orgs:
        - name: myorg
          teams:
          - platform-team
          - developers
```

## Custom health checks

```yaml
# argocd-cm
data:
  resource.customizations.health.argoproj.io_Rollout: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.phase == "Healthy" then
        hs.status = "Healthy"
        return hs
      end
    end
    hs.status = "Progressing"
    hs.message = "Rollout in progress"
    return hs
```

## CLI reference

```bash
# Application lifecycle
argocd app list
argocd app get <app> [--refresh] [--hard-refresh]
argocd app sync <app> [--prune] [--dry-run] [--force] [--timeout 300]
argocd app diff <app>
argocd app history <app>
argocd app rollback <app> <revision>
argocd app logs <app> [--follow] [--container <name>]
argocd app resources <app>
argocd app delete <app> [--cascade=false]

# Repo management
argocd repo add <url> --username <u> --password <token>
argocd repo list

# Cluster management
argocd cluster add <context>
argocd cluster list

# Project management
argocd proj list
argocd proj get <project>
```

## Status reference

| Sync status | Meaning |
|:------------|:--------|
| Synced | Live state matches Git |
| OutOfSync | Drift detected |
| Unknown | Cannot determine |

| Health status | Meaning |
|:--------------|:--------|
| Healthy | All resources healthy |
| Progressing | Resources being updated |
| Degraded | One or more resources unhealthy |
| Suspended | Resources suspended |
| Missing | Resources absent from cluster |

## Troubleshooting

**App stuck OutOfSync after correct Git state:**

```bash
argocd app get <app> --hard-refresh
argocd app diff <app>
```

**ComparisonError (Kustomize/Helm render failure):**
- Hard-refresh to clear the repo-server cache.
- Check the `conditions` field in `argocd app get` output for the render error.

**Sync stuck / hook not completing:**
- Check hook pod logs: `argocd app logs <app>`.
- Verify `hook-delete-policy` -- `HookSucceeded` leaves failed hook pods visible for inspection.

**Authentication expired:**

```bash
argocd login <server> --username admin --password <password> [--insecure]
```

## Best practices

- One Application per logical component, not one giant app per cluster.
- Enable `prune: true` and `selfHeal: true` in production.
- Use AppProjects to enforce source/destination boundaries per team.
- Use sync waves to sequence dependent resources (e.g., CRDs before CRs).
- Use `syncWindows` to gate production deployments to business hours.
- Implement `orphanedResources.warn: true` to surface drift early.
- Prefer `ServerSideApply=true` for large resources to avoid annotation size limits.
- Enable Go templates with `goTemplateOptions: ["missingkey=error"]` in all ApplicationSets.
- Use `spec.sources` (multi-source) when Helm values live in a separate repo from the chart.

## Anti-patterns

- No `prune` -- leaves orphaned resources that accumulate silently.
- No AppProject -- loses namespace/repo isolation, no RBAC boundaries.
- Manual syncs only -- defeats the point of GitOps; drift goes undetected.
- Overloading one Application with unrelated resources -- makes rollback and diff noisy.
- Using legacy fasttemplate syntax (`{{field}}`) in new ApplicationSets -- Go templates with `missingkey=error` catch typos at render time.
