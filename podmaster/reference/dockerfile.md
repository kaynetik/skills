# Dockerfile and Containerfile optimization

Applies to **`docker build`**, **`podman build`**, and BuildKit frontends. File name is `Dockerfile` (Docker convention) or `Containerfile` (Podman convention); both tools accept either name.

## Core workflow

1. **Analyze** the existing file for cache misses, oversized layers, secrets in `ARG`/`ENV`, and a missing non-root user.
2. **Split stages**: build tools go in builder stages; the final stage contains only what the process needs at runtime.
3. **Order** instructions from stable to volatile to maximize cache reuse.
4. **Shrink** the final stage: slim, distroless, or scratch as appropriate for the stack.
5. **Harden**: set `USER`, define `HEALTHCHECK`, and add OCI labels.

## Base image selection

| Stack | Common production bases | Notes |
| :--- | :--- | :--- |
| Node | `node:*-bookworm-slim`, `node:*-alpine`, distroless Node | Match glibc if native addons are present |
| Python | `python:*-slim`, distroless Python | Use a venv to isolate deps from the system Python |
| Go | `golang:*` builder, `gcr.io/distroless/static` or `scratch` | `CGO_ENABLED=0` enables a fully static binary |
| Rust | `rust`/`cargo-chef` builder, `debian:bookworm-slim` or `distroless/cc` | musl vs glibc is a linking decision, not a style choice |
| JVM | `eclipse-temurin:*-jdk` builder, `eclipse-temurin:*-jre` runtime | Never ship the full JDK in the runtime stage |

Pin **minor/patch** versions in the `FROM` tag. For highest reproducibility, pin by digest (`FROM base@sha256:...`).

## Multi-stage pattern (Go example)

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.23-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
```

## Layer caching rules

- Copy **dependency manifests** (lockfile, `go.sum`, `requirements.txt`, `package-lock.json`) before copying source, then install, then `COPY .`.
- Combine `apt-get update`, `install`, and cleanup into a **single `RUN`** so the intermediate data is not preserved in a separate layer:

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc ca-certificates && \
    rm -rf /var/lib/apt/lists/*
```

- Use **BuildKit cache mounts** to persist package manager caches across builds without committing them to the image:

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends gcc
```

## `.dockerignore` / `.containerignore`

Always include one. Minimum exclusions:

```
.git
.env*
node_modules
target/
dist/
*.log
```

A missing ignore file sends the full working directory to the build daemon on every build, breaks caching when unrelated files change, and risks leaking credentials from `.env` files.

## Security

- **No secrets** in `ENV` or `ARG` in the final stage. Use BuildKit secrets for build-time tokens (`--mount=type=secret`); inject runtime secrets via the orchestrator.
- **Non-root user**: create with `RUN adduser` (or equivalent), then `COPY --chown=user:group` and `USER user`.
- **Distroless and scratch** images have no shell. Health checks must use binary probes or orchestrator-native probes (Kubernetes `exec`/`httpGet`/`tcpSocket`).
- **Labels** for traceability:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/org/repo"
LABEL org.opencontainers.image.revision="$GIT_SHA"
LABEL org.opencontainers.image.version="$VERSION"
```

## HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1
```

Use `wget` (Alpine) or `curl` (Debian/Ubuntu). For images without either, use a small binary probe or rely entirely on orchestrator probes.

## Anti-patterns

| Pattern | Problem |
| :--- | :--- |
| `COPY . .` before installing deps | Invalidates dep install cache on every source change |
| Separate `RUN apt-get update` layers | Cleanup in a later layer does not reduce image size |
| `FROM base:latest` in production | Non-reproducible; breaks on upstream changes |
| Debug tools (gdb, strace) in final stage | Increases attack surface; move to a separate debug target |
| `ADD` instead of `COPY` for local files | `ADD` has implicit tar extraction and URL fetch; `COPY` is explicit |

## Podman-specific notes

- `podman build` reads the same instruction set. Advanced BuildKit syntax (`--mount=type=cache`) requires `podman build` with a compatible buildkitd or the built-in BuildKit support in recent Podman versions -- check `podman version` and docs.
- Rootless builds operate with mapped UIDs; `COPY --chown` values are relative to the container's user namespace, which may differ from the host UID.
