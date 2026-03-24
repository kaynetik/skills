---
name: devops-iac-engineer
description: Implements infrastructure as code using Terraform, Kubernetes, and cloud platforms. Designs scalable architectures, CI/CD pipelines, and observability solutions. Provides security-first DevOps practices and site reliability engineering guidance.
---

# DevOps IaC Engineer

Guidance for designing, implementing, and maintaining cloud infrastructure using Infrastructure as Code principles.

## Reference Files

- **Terraform & IaC**: [terraform.md](reference/terraform.md) -- workspaces, modules, state management, naming conventions
- **GCP**: [gcp.md](reference/gcp.md) -- VPC, GKE, Cloud SQL, Cloud Run, IAM, Secret Manager, cost
- **Kubernetes**: [kubernetes.md](reference/kubernetes.md) -- deployments, services, RBAC, Helm
- **Cloud Platforms**: [cloud_platforms.md](reference/cloud_platforms.md) -- AWS, Azure, GCP comparison, multi-cloud, DR
- **CI/CD & GitOps**: [cicd.md](reference/cicd.md) -- pipelines, ArgoCD, Flux, deployment strategies
- **Observability**: [observability.md](reference/observability.md) -- metrics, logging, tracing, SLI/SLO
- **Security**: [security.md](reference/security.md) -- secrets, container security, network policies, compliance
- **Templates**: [templates.md](reference/templates.md) -- EKS, GKE, RDS, Cloud SQL, CI/CD, Makefile configs

## Terminology

- **Infrastructure as Code (IaC)**: managing infrastructure through declarative code
- **GitOps**: Git as the single source of truth for infrastructure and applications
- **Immutable Infrastructure**: components replaced rather than modified in place
- **Observability**: understanding system state from external outputs (logs, metrics, traces)
- **SLI/SLO/SLA**: Service Level Indicators/Objectives/Agreements
- **RTO/RPO**: Recovery Time Objective/Recovery Point Objective

## Implementation Workflow

1. **Understand requirements** -- business need, scale, constraints, dependencies
2. **Design architecture** -- cloud platform, HA, network topology, data flows
3. **Select tooling** -- Terraform for provisioning, Kubernetes for orchestration, CI/CD platform
4. **Implement IaC** -- modular code, state management, naming conventions, tagging
5. **Set up observability** -- define SLIs/SLOs, logging, metrics, tracing, alerting
6. **Build CI/CD** -- pipeline stages, automated testing, GitOps, deployment strategy
7. **Test and validate** -- security scans, compliance checks, DR drills, load testing
8. **Deploy and monitor** -- phased rollout, metric validation, runbooks

## Tool Selection

**Multi-Cloud** -- Terraform or OpenTofu
**Container Orchestration** -- Kubernetes (EKS, GKE, AKS)
**Simple Containers** -- ECS, Cloud Run, or App Service
**Configuration Management** -- Ansible or cloud-native solutions
**GitOps** -- ArgoCD
**CI/CD** -- GitHub Actions, GitLab CI, or Jenkins

## Common Problems

**Infrastructure drift** -- automated drift detection, `terraform plan` in CI, read-only production access, state file integrity

**Secrets exposure** -- cloud-native secret managers (AWS Secrets Manager, GCP Secret Manager, Vault), SOPS for encrypted secrets in Git, IRSA/Workload Identity

**Cost overruns** -- tagging strategy, cost allocation tags, budget alerts, right-sizing, spot instances, auto-scaling

**Complex K8s configs** -- Helm for templating, Kustomize for environment overlays, GitOps for declarative state, operators for stateful workloads
