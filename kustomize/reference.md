# Kustomize reference notes

## Upstream documentation

- [Kustomize project site](https://kustomize.io/) -- overview, ecosystem links
- [Kubernetes task: Declarative management using Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) -- generators, patches, bases and overlays, kubectl `-k`
- [Managing Secrets using Kustomize](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kustomize/) -- secretGenerator patterns and caveats

## kustomization fields (non-exhaustive)

The Kubernetes task doc maintains a feature table. Commonly used fields include:

- `resources`, `components`
- `namespace`, `namePrefix`, `nameSuffix`
- `commonLabels`, `commonAnnotations`, `labels`
- `patches` (strategic merge and JSON patch with targets)
- `images`, `replicas`, `replacements`
- `configMapGenerator`, `secretGenerator`, `generatorOptions`
- `configurations` (advanced transformer config)
- `crds` (OpenAPI for CRDs when needed for strategic merge)
- `helmCharts` (when enabled in the toolchain)

## Version and tooling

- Confirm `kubectl version` and standalone `kustomize version` when debugging subtle transform differences
- Pin the same major.minor in CI, local dev, and GitOps agents when feasible

## Security reminders

- Prefer secret files excluded by `.gitignore` or external secret systems over literals in tracked YAML
- Audit remote bases when pins move; diff rendered manifests in CI
