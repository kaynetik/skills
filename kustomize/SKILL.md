---
name: kustomize
description: Kubernetes configuration customization with Kustomize: base and overlay layout, strategic and JSON patches, configMapGenerator and secretGenerator, images, components, replacements, and remote bases. Use when authoring kustomization.yaml, debugging kubectl kustomize or kubectl apply -k, layering environments, GitOps manifests, or when the user mentions Kustomize, kustomization.yaml, overlay, patch, or kubectl -k.
---

# Kustomize

Template-free customization of Kubernetes manifests. Prefer plain YAML, small patches, and explicit composition over copying entire files per environment.

## When to use this skill

- Structuring repos with a shared base and environment overlays
- Patching upstream or third-party manifests without forking
- Generating ConfigMaps and Secrets from files or literals
- Changing images, labels, namespaces, and cross-cutting metadata consistently
- Validating rendered YAML before apply or GitOps sync

## Layout

Keep the base environment-agnostic; put environment differences in overlays.

```text
myapp/
  base/
    kustomization.yaml
    deployment.yaml
    service.yaml
  overlays/
    dev/
      kustomization.yaml
      patches/
    staging/
      kustomization.yaml
    prod/
      kustomization.yaml
      patches/
```

## Minimal kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

Use `apiVersion: kustomize.config.k8s.io/v1beta1` unless the toolchain requires a different documented version.

## Bases and overlays

The overlay lists the base (or another kustomization directory) under `resources` and adds transforms and patches.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: myapp-prod

namePrefix: prod-

patches:
  - path: replicas.yaml
```

Rules of thumb:

- Bases must not reference overlays
- One overlay directory should correspond to one deployable variant (cluster, env, or tenant slice)
- Prefer several small patches over one large patch file

## Cross-cutting fields

| Field | Use |
| :--- | :--- |
| `namespace` | Set metadata.namespace on all resources |
| `namePrefix` / `nameSuffix` | Prefix or suffix resource names |
| `commonLabels` | Add labels to resources and, by default, to selectors |
| `commonAnnotations` | Add annotations to all resources |
| `labels` | List of `{ pairs, includeSelectors }` entries for labels; set `includeSelectors: false` to skip selector updates |

> [!WARNING]
> `commonLabels` updates label selectors on workloads. That can break Deployments if selector keys no longer match pod template labels, or if you add labels that must not participate in selection. For metadata-only labels on newer Kustomize, prefer the `labels` list form with `pairs` and `includeSelectors: false` instead of expanding `commonLabels`.

Align with [Kubernetes recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) where practical (`app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`).

## Patches

### Strategic merge (default file patches)

Patch file `kind` and `metadata.name` must match the target resource.

```yaml
patches:
  - path: increase-replicas.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
```

### JSON patch (RFC 6902)

Use when you need precise path edits or types that do not merge cleanly.

```yaml
patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: myapp
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 5
```

Prefer `patches` with `target` over legacy `patchesJson6902` in new work when the toolchain supports it.

### Patch targets

Narrow targets with `name`, `namespace`, `labelSelector`, or `annotationSelector` so patches do not hit the wrong resource after refactors.

## Generators

### configMapGenerator

```yaml
configMapGenerator:
  - name: app-config
    literals:
      - LOG_LEVEL=info
    files:
      - application.properties
    envs:
      - config.env
```

- `files`: each file becomes one key (file name as key) unless you use `key=path`
- `envs`: each variable in the env file becomes its own key (different from embedding a whole file)

### secretGenerator

```yaml
secretGenerator:
  - name: app-tls
    type: kubernetes.io/tls
    files:
      - tls.crt=certs/tls.crt
      - tls.key=certs/tls.key
```

> [!CAUTION]
> Do not commit real secrets. For literals and files that contain credentials, use a secret manager, SOPS, External Secrets, or CI-injected files that stay out of git. Treat `secretGenerator` literals as non-production or bootstrap-only.

### Generator names and rollouts

By default Kustomize appends a content hash suffix to generated ConfigMap and Secret names so dependent pods roll when data changes. Reference the generator base name in Deployments; Kustomize rewrites references to the hashed name.

- Use `options.disableNameSuffixHash: true` only when you must keep a stable name (integrates poorly with rollouts on change)
- Use `options.immutable: true` on ConfigMaps when you want immutability guarantees and your policy allows it

### behavior in overlays

Use `behavior: merge` to combine generator entries across layers; use `replace` only when you intentionally replace the whole generated object. Wrong behavior causes confusing conflicts or silent overrides.

## images

```yaml
images:
  - name: myapp
    newName: registry.example.com/myorg/myapp
    newTag: "1.2.3"
```

`name` matches the image string in manifests before transforms. For digests, use `digest` instead of `newTag` when pinning.

## replacements

Copy field values between objects (for example inject a Service name after `namePrefix` without hardcoding the final string).

```yaml
replacements:
  - source:
      kind: Service
      name: myapp
      fieldPath: metadata.name
    targets:
      - select:
          kind: Deployment
          name: myapp
        fieldPaths:
          - spec.template.spec.containers.[name=myapp].env.[name=SERVICE_HOST].value
```

Prefer `replacements` over fragile sed-style edits in docs or scripts.

## components

Optional reusable slices (monitoring sidecar, network policy bundle) referenced from overlays.

```yaml
components:
  - ../../components/monitoring
```

Keep components focused; avoid cycles between components and overlays.

## Remote resources

```yaml
resources:
  - https://github.com/org/manifests//deploy/base?ref=v1.4.2
```

Always pin `ref` to a tag or commit SHA. Treat remote bases like supply chain inputs: review upgrades, vendor or mirror when policy requires, and record the pin in change logs.

> [!IMPORTANT]
> Embedded Kustomize in `kubectl` can lag the standalone `kustomize` binary. If behavior differs, compare versions and standardize the tool in CI and GitOps controllers on one supported release line.

## helmCharts (optional)

Some Kustomize builds support rendering Helm charts from `kustomization.yaml`. If you use this, pin chart `version`, record values files in git, and validate rendered output. Prefer native Helm workflows when Helm is the primary packaging format.

## Validation workflow

Run before every apply or merge:

```bash
kubectl kustomize overlays/prod > /tmp/rendered.yaml
kubectl apply --dry-run=client -f /tmp/rendered.yaml
```

In GitOps, ensure the same `kustomize build` (or controller-equivalent) runs in CI so the cluster never sees untested composition.

## GitOps alignment

- Argo CD and Flux both consume Kustomize; keep the kustomization root explicit in Application or Kustomization CRs
- Avoid non-hermetic fetches in production paths unless your policy allows them and they are pinned
- Split "platform" and "application" bases when different teams own lifecycles

## Common failure modes

| Symptom | Likely cause |
| :--- | :--- |
| Patch did nothing | Wrong `metadata.name`, wrong `kind`, or target selector too broad or too narrow |
| Pods did not restart on config change | `disableNameSuffixHash: true` or reference does not go through Kustomize name transformation |
| Selector mismatch after label change | `commonLabels` changed selectors; switch to `labels` with `includeSelectors: false` or fix template or selector keys |
| Duplicate resource errors | Two layers both `create` the same generated name; use `merge` or rename |
| Remote build flaky | Unpinned `ref`, network policy, or rate limits on Git hosts |

## Additional resources

For a short link list and notes on upstream docs, see [reference.md](reference.md).
