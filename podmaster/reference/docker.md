# Docker Engine and Compose

Applies to **Docker Engine** (Moby) with the `docker` CLI. Commands are largely identical to Podman; differences are noted in [podman.md](podman.md).

## CLI essentials

```bash
docker build -t myapp:1.0.0 .
docker buildx build --platform linux/amd64 -t myapp:1.0.0 --push .
docker run -d --name app -p 8080:8080 myapp:1.0.0
docker logs -f app
docker exec -it app sh
docker inspect app
docker stats app
```

## BuildKit

Modern builds use **BuildKit** (default since Docker 23). Key features:

- Cache mounts: `RUN --mount=type=cache,target=...`
- Build-time secrets: `RUN --mount=type=secret,id=token`
- SSH agent forwarding: `RUN --mount=type=ssh`
- Provenance and SBOM attestations (opt-in via `--provenance`, `--sbom`).

```bash
docker buildx ls
docker buildx build -f Dockerfile --target production -t myapp:prod .
```

For CI, use **registry cache** (`--cache-from type=registry,...`) or the GitHub Actions cache exporter (`type=gha`). Check the project's BuildKit docs for exact flags -- they vary by builder version.

## Compose

**Compose v2** (`docker compose`) reads `compose.yaml` or `docker-compose.yml`.

```bash
docker compose up -d --build
docker compose logs -f service_name
docker compose exec service_name sh
docker compose down -v
```

- Use **profiles** for optional services (`--profile dev`).
- Use `depends_on` with `condition: service_healthy` for startup ordering, which requires a `healthcheck` on the dependency.

## Contexts and remotes

```bash
docker context ls
docker context create remote --docker "host=ssh://user@host"
DOCKER_CONTEXT=remote docker build -t myapp .
```

Building on a remote host avoids syncing a large local context over SSH for each layer.

## Swarm

Swarm mode (`docker stack deploy`) is maintenance-mode. For new orchestration work, use Kubernetes unless Swarm is an existing organizational constraint.

## Docker vs Podman quick comparison

| Concept | Docker | Podman |
| :--- | :--- | :--- |
| Daemon | `dockerd` required | daemonless by default |
| Socket | `/var/run/docker.sock` | `~/.local/share/containers/...` (rootless) |
| Compose | `docker compose` | `podman compose` |
| Root default | yes (rootful) | no (rootless) |
| Pods | via Compose networks | native pod concept |

When targeting Podman, note that Containerfile is the preferred name (though `podman build -f Dockerfile` works the same way).
