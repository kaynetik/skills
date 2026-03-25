# OCI runtimes and CRI

This reference covers OCI bundle execution, low-level runtimes, the containerd shim model, and the Kubernetes CRI so you know which binary owns which part of the call chain and which tool to reach for when something goes wrong.

## OCI specs

| Spec | What it defines |
| :--- | :--- |
| **Image spec** | Manifest format, layer blobs (tar, zstd), image config (env, entrypoint, user) |
| **Runtime spec** | `config.json` bundle structure; what the low-level runtime receives |
| **Distribution spec** | Registry HTTP API for push/pull |

Implementations are interchangeable at OCI boundaries. Behavioral differences surface in defaults (user namespace handling, cgroup version, seccomp profiles).

## Low-level runtimes

| Runtime | Language | Notes |
| :--- | :--- | :--- |
| **runc** | Go | OCI reference implementation; shipped with Docker Engine and containerd |
| **crun** | C | Faster startup and lower memory overhead; default on Fedora/RHEL with Podman |
| **youki** | Rust | Experimental; compatible with runc at the OCI spec level |
| **kata-containers** | Go + VM | Runs each container in a lightweight VM for stronger isolation; CRI-compatible |

The higher-level runtime (containerd, dockerd, Podman) prepares the OCI bundle and invokes `runc` or `crun`.

## containerd shim

containerd spawns one **shim process** per container (`containerd-shim-runc-v2`). The shim:

- Owns the container stdio after the API call returns.
- Reports the exit code back to containerd when the process terminates.
- Survives a containerd restart without killing the container.

If the shim hangs, containers may linger and logs may stop flowing. Check node journals and `ctr tasks ls` before killing shim processes on a production node.

## Kubernetes CRI (Container Runtime Interface)

**kubelet** communicates with the container runtime over a gRPC socket defined by the CRI:

- `RuntimeService`: RunPodSandbox, CreateContainer, StartContainer, StopContainer, RemoveContainer, ExecSync, ...
- `ImageService`: PullImage, ListImages, RemoveImage, ...

CRI implementations:

| Implementation | Notes |
| :--- | :--- |
| **containerd** (built-in CRI plugin) | Default for most Kubernetes distributions since 1.24 |
| **CRI-O** | Kubernetes-only runtime; no Docker daemon involved |

## What to use when

| Situation | Tool |
| :--- | :--- |
| Kubernetes pod fails to start | `kubectl describe pod`, `kubectl logs --previous`, **crictl ps -a** |
| Is the image present on the node? | `crictl images`, `ctr -n k8s.io images ls` |
| Sandbox (pause container) issue | `crictl pods`, `crictl inspectp <pod-id>` |
| Low-level runc/crun error | `crictl inspect <container-id>` state message; node systemd journal |
| Snapshot / layer issue | `ctr -n k8s.io snapshots ls`, containerd logs |
| Docker-only host | `docker inspect`, `docker logs`, `docker exec` |
| Podman-only host | `podman inspect`, `podman logs`, `podman exec` |

## Docker and Kubernetes

Kubernetes has not used Docker Engine as the node runtime since **dockershim was removed in 1.24**. Nodes run containerd (or CRI-O). Tools like **kind** and **minikube** may surface a `docker` CLI on the host for image loading, but the node runtime is CRI-based internally.

## Podman and Kubernetes

Podman's pod model mirrors the Kubernetes pod (shared network namespace, pause container concept). `podman kube play` and `podman generate kube` allow local iteration on Kubernetes YAML, but production scheduling still goes through the CRI on cluster nodes.

## Further reading

- [Kubernetes Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [OCI Runtime spec](https://github.com/opencontainers/runtime-spec)
- [containerd architecture](https://github.com/containerd/containerd/blob/main/docs/PLUGINS.md)
