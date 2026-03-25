# Podman

**Podman** is a daemonless, rootless-first container engine. Its CLI is intentionally close to Docker; many scripts run unmodified with `alias docker=podman`.

Official docs: [docs.podman.io](https://docs.podman.io/).

## Lifecycle

```bash
podman run -d --name my-app -p 8080:80 quay.io/libpod/hello:latest
podman ps -a
podman logs -f my-app
podman exec -it my-app sh
podman stop my-app && podman rm my-app
```

## Rootless

Default for normal users. Requires **subuid/subgid** ranges in `/etc/subuid` and `/etc/subgid` for user namespace UID mapping. If mapping errors appear, fix the ranges before chasing application errors.

```bash
podman info
```

Check the `rootless` flag and `cgroupVersion` in the output.

## Images and build

```bash
podman pull alpine:3.21
podman build -t myimg:latest -f Containerfile .
podman images
podman rmi myimg:latest
```

Podman accepts `Dockerfile` and `Containerfile` interchangeably. It also reads `.containerignore`, falling back to `.dockerignore`. Apply the same optimization rules as [dockerfile.md](dockerfile.md).

## Pods (shared network namespace)

Pods group containers under a single network namespace so services on different containers reach each other via `localhost`.

```bash
podman pod create --name webapp -p 8080:80
podman run -d --pod webapp --name nginx docker.io/library/nginx:alpine
podman pod ps
podman pod rm -f webapp
```

## Compose

```bash
podman compose up -d
podman compose down
```

Requires a compatible compose backend. Verify versions in the docs if behaviour diverges from Docker Compose.

## Quadlet (systemd integration)

**Quadlet** is the current method for managing Podman containers as systemd units. Place `.container`, `.kube`, or `.volume` files in `~/.config/containers/systemd/` (rootless) or `/etc/containers/systemd/` (root).

```ini
# ~/.config/containers/systemd/my-app.container
[Container]
Image=docker.io/library/nginx:alpine
PublishPort=8080:80

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user start my-app
```

`podman generate systemd` still exists but is deprecated since Podman 4.4 in favor of Quadlet. Prefer Quadlet for new setups.

## Secrets

```bash
printf 'value' | podman secret create my_secret -
podman run --secret my_secret,type=env,target=SECRET_ENV ...
```

## Kubernetes interop

```bash
podman generate kube my-pod > pod.yaml
podman kube play pod.yaml
podman kube down pod.yaml
```

Useful for smoke-testing Kubernetes manifests locally; not a substitute for cluster workflows.

## Auto-updates

Add `io.containers.autoupdate=registry` on a container managed by a Quadlet unit, then run:

```bash
podman auto-update
```

This pulls updated digests from the registry and restarts affected units.

## Compatibility notes

- **cgroups v2** is expected on modern Linux. macOS runs Podman inside a Linux VM (`podman machine`).
- Volume bind-mounts on RHEL/Fedora require SELinux labels (`:Z` for private, `:z` for shared) when SELinux is enforcing.
- The Podman socket API is Docker-compatible; tools that speak the Docker HTTP API (e.g., some CI systems) can target it with `DOCKER_HOST=unix:///run/user/<uid>/podman/podman.sock`.
