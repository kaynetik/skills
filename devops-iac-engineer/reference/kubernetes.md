# Kubernetes & Container Orchestration

## Kubernetes Architecture Essentials

### Core Components
- **Control Plane**: API Server, Scheduler, Controller Manager, etcd
- **Worker Nodes**: Kubelet, Kube-proxy, Container Runtime
- **Add-ons**: CoreDNS, Metrics Server, Gateway Controller

### Key Kubernetes Resources
- **Workloads**: Pods, Deployments, StatefulSets, DaemonSets, Jobs, CronJobs
- **Networking**: Services, Gateway API, NetworkPolicies
- **Configuration**: ConfigMaps, Secrets
- **Storage**: PersistentVolumes, PersistentVolumeClaims, StorageClasses
- **Access Control**: ServiceAccounts, Roles, RoleBindings, ClusterRoles, ClusterRoleBindings

## Production-Ready Deployment Pattern

### Deployment with Best Practices
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
  labels:
    app: myapp
    version: v1.0.0
    environment: production
spec:
  replicas: 3
  revisionHistoryLimit: 10

  # Deployment strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # Zero-downtime deployment

  selector:
    matchLabels:
      app: myapp

  template:
    metadata:
      labels:
        app: myapp
        version: v1.0.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"

    spec:
      # Security context at pod level
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault

      # Service account for pod identity
      serviceAccountName: myapp

      # Init container for setup tasks
      initContainers:
      - name: init-config
        image: busybox:1.36
        command: ['sh', '-c', 'echo Initializing... && sleep 2']
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
              - ALL

      containers:
      - name: myapp
        image: myapp:1.0.0
        imagePullPolicy: IfNotPresent

        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            # No CPU limit -- requests guarantee scheduling; limits cause
            # throttling even when the node has spare capacity. Set CPU
            # limits only for I/O-bound or latency-critical workloads that
            # need strict isolation.

        # Container security
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
              - ALL

        # Health checks
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3

        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 30  # 5 minutes max startup time

        # Environment variables
        env:
        - name: ENV
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP

        # Environment from ConfigMap
        envFrom:
        - configMapRef:
            name: myapp-config
        - secretRef:
            name: myapp-secrets

        # Container ports
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP

        # Volume mounts
        volumeMounts:
        - name: config
          mountPath: /etc/myapp
          readOnly: true
        - name: secrets
          mountPath: /etc/secrets
          readOnly: true
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache

      # Volumes
      volumes:
      - name: config
        configMap:
          name: myapp-config
      - name: secrets
        secret:
          secretName: myapp-secrets
          defaultMode: 0400
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}

      # Pod scheduling
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - myapp
              topologyKey: kubernetes.io/hostname

      # Tolerations for node taints
      tolerations:
      - key: "node-role.kubernetes.io/spot"
        operator: "Exists"
        effect: "NoSchedule"
```

### Service Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: production
  labels:
    app: myapp
  annotations:
    # AWS: service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    # GCP: cloud.google.com/l4-rbs: "enabled"
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8443
    protocol: TCP

  # Session affinity (optional)
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-headless
  namespace: production
spec:
  clusterIP: None  # Headless service for StatefulSets
  selector:
    app: myapp
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

### Gateway API (Recommended)

Gateway API is the successor to Ingress and the recommended approach for new deployments. It provides role-oriented resource modeling, advanced routing, and works consistently across implementations (Envoy, Istio, Traefik, NGINX Gateway Fabric).

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: production
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller

---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production
  namespace: production
spec:
  gatewayClassName: production
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: myapp-tls
    allowedRoutes:
      namespaces:
        from: Same

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
  namespace: production
spec:
  parentRefs:
  - name: production
  hostnames:
  - myapp.example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: myapp
      port: 8080
      weight: 100
```

Gateway API supports weight-based traffic splitting, header matching, URL rewrites, and request mirroring natively -- without vendor-specific annotations.

### Ingress (Legacy)

Ingress NGINX is retiring (best-effort maintenance ending March 2026). Use Gateway API for new deployments. Existing Ingress resources can be migrated with `ingress2gateway`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 8080
```

## Configuration Management

### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: production
data:
  # Simple key-value pairs
  app.env: "production"
  log.level: "info"

  # Multi-line configuration files
  application.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    database:
      max_connections: 100
      timeout: 30s
    cache:
      ttl: 3600
      max_size: 1000
```

### Secrets Management
```yaml
# NOT RECOMMENDED - Base64 is not encryption!
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
  namespace: production
type: Opaque
data:
  db-password: xxxxxx  # base64 encoded

---
# BETTER - Use Sealed Secrets
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: myapp-secrets
  namespace: production
spec:
  encryptedData:
    db-password: AgBqV7zJ8...  # Encrypted with controller's public key

---
# BEST - Use External Secrets Operator (works with AWS, GCP, Azure, Vault)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: cloud-secrets
  namespace: production
spec:
  provider:
    # AWS Secrets Manager:
    # aws:
    #   service: SecretsManager
    #   region: us-east-1
    #   auth:
    #     jwt:
    #       serviceAccountRef:
    #         name: myapp

    # GCP Secret Manager:
    gcpsm:
      projectID: my-project-id

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-secrets
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: cloud-secrets
    kind: SecretStore

  target:
    name: myapp-secrets
    creationPolicy: Owner

  data:
  - secretKey: db-password
    remoteRef:
      key: prod-myapp-db-password
  - secretKey: api-key
    remoteRef:
      key: prod-myapp-api-key
```

## StatefulSets for Stateful Applications

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
spec:
  serviceName: postgres-headless
  replicas: 3

  selector:
    matchLabels:
      app: postgres

  template:
    metadata:
      labels:
        app: postgres
    spec:
      securityContext:
        fsGroup: 999
        runAsUser: 999

      containers:
      - name: postgres
        image: postgres:15-alpine

        env:
        - name: POSTGRES_DB
          value: myapp
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata

        ports:
        - name: postgres
          containerPort: 5432

        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"

        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 5
          periodSeconds: 5

        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data

  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      # AWS: gp3 | GCP: premium-rwo | Azure: managed-csi-premium
      storageClassName: gp3
      resources:
        requests:
          storage: 100Gi
```

## Autoscaling

### Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp

  minReplicas: 3
  maxReplicas: 20

  metrics:
  # CPU-based scaling
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

  # Memory-based scaling
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

  # Custom metrics (requires metrics adapter)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

### Vertical Pod Autoscaler (VPA)
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp

  updatePolicy:
    updateMode: "Auto"  # "Off", "Initial", "Recreate", or "Auto"

  resourcePolicy:
    containerPolicies:
    - containerName: myapp
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2000m
        memory: 2Gi
      controlledResources:
      - cpu
      - memory
```

## Pod Security Standards

Enforce security at the namespace level using Pod Security Admission (PSA). PSA replaced PodSecurityPolicy (removed in K8s 1.25) and is GA since K8s 1.25.

Three profiles: **Privileged** (unrestricted), **Baseline** (prevents known escalations), **Restricted** (hardened -- matches the securityContext patterns used in this document).

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Use `audit` and `warn` modes during migration to detect violations without blocking deployments. Switch to `enforce` once workloads comply.

For more granular policy control beyond the three built-in profiles, pair PSA with admission webhooks (OPA Gatekeeper, Kyverno) or see [security.md](security.md) for policy-as-code patterns.

## RBAC (Role-Based Access Control)

### ServiceAccount, Role, and RoleBinding
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
  namespace: production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: myapp-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myapp-rolebinding
  namespace: production
subjects:
- kind: ServiceAccount
  name: myapp
  namespace: production
roleRef:
  kind: Role
  name: myapp-role
  apiGroup: rbac.authorization.k8s.io
```

### ClusterRole for Cluster-Wide Permissions
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-pods-global
subjects:
- kind: ServiceAccount
  name: myapp
  namespace: production
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

## Network Policies

### Restrict Ingress Traffic
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: myapp-netpol
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp

  policyTypes:
  - Ingress
  - Egress

  ingress:
  # Allow traffic from nginx ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 8080

  # Allow traffic from prometheus for metrics
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 9090

  egress:
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53

  # Allow database access
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432

  # Allow external HTTPS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
```

## Jobs and CronJobs

### Job for One-Time Task
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  namespace: production
spec:
  backoffLimit: 3
  activeDeadlineSeconds: 600  # 10 minutes timeout

  template:
    metadata:
      labels:
        app: migration
    spec:
      restartPolicy: OnFailure

      containers:
      - name: migrate
        image: myapp:1.0.0
        command: ["/app/migrate"]
        args: ["--direction", "up"]

        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: database-url

        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
```

### CronJob for Scheduled Tasks
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-database
  namespace: production
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  timeZone: "America/New_York"
  concurrencyPolicy: Forbid  # Don't allow concurrent runs
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1

  jobTemplate:
    spec:
      backoffLimit: 2
      activeDeadlineSeconds: 3600  # 1 hour timeout

      template:
        spec:
          restartPolicy: OnFailure

          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME | \
              gzip > /backup/backup-$(date +%Y%m%d-%H%M%S).sql.gz

            envFrom:
            - secretRef:
                name: postgres-secrets

            volumeMounts:
            - name: backup
              mountPath: /backup

          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: backup-pvc
```

## Helm Charts

### Chart Structure
```
myapp-chart/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-prod.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── httproute.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   ├── NOTES.txt
│   └── _helpers.tpl
└── README.md
```

### Chart.yaml
```yaml
apiVersion: v2
name: myapp
description: A Helm chart for MyApp
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - myapp
  - web
maintainers:
  - name: DevOps Team
    email: devops@example.com
dependencies:
  - name: postgresql
    version: "~12.0"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
```

### values.yaml
```yaml
replicaCount: 3

image:
  repository: myapp
  pullPolicy: IfNotPresent
  tag: ""  # Defaults to chart appVersion

imagePullSecrets: []

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}

postgresql:
  enabled: true
  auth:
    username: myapp
    database: myapp
```

### Helm Commands
```bash
# Install chart
helm install myapp ./myapp-chart -n production

# Install with custom values
helm install myapp ./myapp-chart -n production -f values-prod.yaml

# Upgrade release
helm upgrade myapp ./myapp-chart -n production

# Rollback
helm rollback myapp 1 -n production

# Uninstall
helm uninstall myapp -n production

# Template rendering (dry-run)
helm template myapp ./myapp-chart -f values-prod.yaml

# Lint chart
helm lint ./myapp-chart
```

## kubectl Command Reference

```bash
# Get resources
kubectl get pods -n production
kubectl get deployments -n production -o wide
kubectl get svc -n production

# Describe resources
kubectl describe pod myapp-123 -n production
kubectl describe deployment myapp -n production

# Logs
kubectl logs myapp-123 -n production
kubectl logs -f myapp-123 -n production  # Follow
kubectl logs myapp-123 -n production --previous  # Previous container

# Execute commands in pod
kubectl exec -it myapp-123 -n production -- /bin/sh
kubectl exec myapp-123 -n production -- env

# Port forwarding
kubectl port-forward svc/myapp 8080:80 -n production

# Copy files
kubectl cp myapp-123:/tmp/file.txt ./file.txt -n production

# Scale deployment
kubectl scale deployment myapp --replicas=5 -n production

# Rollout management
kubectl rollout status deployment/myapp -n production
kubectl rollout history deployment/myapp -n production
kubectl rollout undo deployment/myapp -n production

# Apply/Delete manifests
kubectl apply -f deployment.yaml
kubectl delete -f deployment.yaml

# Resource usage
kubectl top nodes
kubectl top pods -n production

# Debug
kubectl run debug --image=busybox:1.36 -it --rm --restart=Never -- sh
```

---

## Best Practices Summary

1. **Set resource requests; set memory limits; skip CPU limits** for application workloads
2. **Implement all three health probes** (liveness, readiness, startup)
3. **Use non-root containers** with security contexts matching the `restricted` PSS profile
4. **Enforce Pod Security Standards** at namespace level via PSA labels
5. **Enable RBAC** with namespace-scoped roles; avoid ClusterRoleBindings where possible
6. **Implement network policies** for zero-trust networking
7. **Use Gateway API** for traffic routing; migrate from Ingress
8. **Use External Secrets Operator** with cloud-native secret managers (never commit secrets)
9. **Label everything** consistently (`app`, `version`, `environment`, `team`)
10. **Implement HPA** for auto-scaling; combine with VPA in recommendation mode
11. **Use readOnlyRootFilesystem** and drop all capabilities
