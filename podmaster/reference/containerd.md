# containerd

**containerd** is a high-level container runtime that manages image distribution, storage (via the snapshottor), and container lifecycle. Kubernetes uses containerd via its built-in **CRI plugin**; Docker Engine also uses containerd as its execution backend.

Official site: [containerd.io](https://containerd.io/).

## Role in the stack

| Component | Responsibility |
| :--- | :--- |
| **containerd** | Pull/push images, manage snapshots, create/delete containers via CRI or the containerd API |
| **shim** (`containerd-shim-runc-v2`) | One process per container; keeps stdio and exit status after the calling process exits |
| **runc / crun** | Executes the OCI bundle; sets up namespaces and cgroups, execs init |
| **kubelet** | Talks CRI (gRPC) to containerd; never talks to Docker Engine |

## ctr (low-level)

`ctr` communicates directly with containerd. Namespaces partition resources; Kubernetes uses the `k8s.io` namespace.

```bash
sudo ctr version
sudo ctr -n k8s.io images ls
sudo ctr -n k8s.io containers ls
sudo ctr -n k8s.io tasks ls
```

Use `ctr` to debug **snapshot** issues, verify image presence on a node, or when `crictl` is not enough. It is not the right tool for routine pod management.

## crictl (CRI-level)

`crictl` speaks the CRI gRPC API and sees the world as the kubelet does: sandboxes (pods) and containers.

```bash
sudo crictl pods
sudo crictl ps -a
sudo crictl logs <container-id>
sudo crictl inspect <container-id>
sudo crictl stats
sudo crictl images
```

Configure the CRI endpoint in `/etc/crictl.yaml`:

```yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
```

## nerdctl

**nerdctl** provides a Docker-compatible UX (run, build, compose) directly against containerd, using buildkitd for image builds. Useful on nodes where Docker Engine is absent.

```bash
nerdctl run -d -p 8080:80 docker.io/library/nginx:alpine
nerdctl compose up -d
```

See [containerd/nerdctl](https://github.com/containerd/nerdctl) for full flag documentation.

## Configuration

`/etc/containerd/config.toml` controls registry mirrors, sandbox image, snapshotter, and CRI plugin settings. Restart containerd after changes -- this affects all running workloads on the node, so plan accordingly in production.

## When to read this reference

- A node cannot pull an image (registry auth, mirror config, TLS).
- Image is pulled but pod is stuck in `CreateContainerError` (snapshot driver, UID mapping, seccomp).
- Comparing what **Kubernetes sees** (`crictl`) with **containerd internals** (`ctr`).

For the full CRI and runtime call chain, see [runtimes-and-cri.md](runtimes-and-cri.md).
