# Container debugging

A structured approach for **Docker**, **Podman**, **containerd**, and **Kubernetes** workloads. Gather facts before changing configuration.

## 1. Symptom and scope

- **Exit code**: `0` is clean exit. `137` typically means OOM kill (SIGKILL). `139` is segfault (SIGSEGV). Codes above `128` are signal-terminated.
- **Restart loop**: note the policy (`always`, `on-failure`, `unless-stopped`) and the backoff interval in orchestrators.
- **Blast radius**: narrow to one replica or one node before investigating application logic.

## 2. Logs

```bash
docker logs --tail 200 -f <container>
podman logs --tail 200 -f <container>
sudo crictl logs <container-id>
kubectl logs <pod> -c <container> --previous
```

`--previous` returns the logs from the last terminated instance. For containers that exit before logging anything, check whether the logging driver is configured correctly and whether the process even starts.

## 3. Inspect state

```bash
docker inspect <container>
podman inspect <container>
kubectl describe pod <pod>
sudo crictl inspect <container-id>
```

Fields to check: `State.ExitCode`, `State.OOMKilled`, `HostConfig.Memory` (limits), `Env`, `Mounts`, `NetworkSettings.Ports`.

## 4. Exec (running containers only)

```bash
docker exec -it <container> sh
podman exec -it <container> sh
kubectl exec -it <pod> -c <container> -- sh
```

If the container exits immediately, share its namespaces from a debug image:

```bash
docker run -it --rm \
  --pid=container:<id> \
  --network=container:<id> \
  nicolaka/netshoot
```

For Kubernetes, use ephemeral debug containers where enabled:

```bash
kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>
```

## 5. Resources

```bash
docker stats <container>
kubectl top pod <pod>
```

Correlate the reported RSS with the configured memory limit. Java (JVM heap + off-heap) and Node (V8 heap + native addons) both need headroom above steady-state. An OOM kill means the limit is too low or there is a leak.

## 6. Networking

Common causes:

- **Port conflict**: another process holds the host port; `ss -tlnp` on the host.
- **DNS failure**: wrong service name, wrong namespace suffix, or missing search path. Test from inside the container with `getent hosts <name>`.
- **TLS/CA**: minimal images (distroless, scratch) do not ship CA certificates. HTTPS to external endpoints fails unless you `COPY` the bundle.

```bash
docker exec <c> getent hosts <hostname>
kubectl run -it --rm netshoot --image=nicolaka/netshoot --restart=Never -- bash
```

## 7. Storage

- **Read-only rootfs**: confirm the path the application writes to is a writable tmpfs or volume.
- **Volume permissions**: the UID inside the container must own or have write permission on the mounted path.
- **Disk pressure on the host**: `docker system df`; prune stopped containers and dangling images.

## 8. Image and entrypoint

- Wrong `CMD` or `ENTRYPOINT`, or a missing binary in `PATH`.
- Shell form (`CMD command arg`) wraps in `/bin/sh -c`, so PID 1 is the shell, not the process -- signals may not propagate. Exec form (`CMD ["command", "arg"]`) makes the process PID 1 directly.

## 9. Tools

| Tool | Use |
| :--- | :--- |
| **dive** | Visualize layers, spot wasted space, identify unexpectedly large files |
| **docker history** / **podman history** | Trace which instruction produced each layer and its size |
| **skopeo** | Inspect remote manifests and digests without pulling the full image |
| **trivy** / **grype** | Scan images for known CVEs; useful locally and in CI |

## Checklist

- [ ] Logs from the current and the previous (crashed) instance
- [ ] Exit code and OOMKilled flag
- [ ] Effective CPU/memory limits and current usage
- [ ] Network: DNS resolution, port binding, TLS certificates
- [ ] Volumes: mount paths, ownership, SELinux context (`:Z`/`:z` on RHEL/Fedora)
- [ ] Image digest and the exact command the runtime is running
