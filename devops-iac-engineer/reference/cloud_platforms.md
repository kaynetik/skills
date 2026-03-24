# Cloud Platforms: AWS, Azure, GCP

## Platform Selection

### AWS (Amazon Web Services)
- Market leader, broadest service catalog, mature ecosystem
- Best for: enterprise workloads, startups, wide service selection
- Key services: EC2, EKS, RDS, S3, Lambda

### Azure (Microsoft Azure)
- Strong enterprise integration, hybrid cloud, Microsoft stack
- Best for: Windows workloads, hybrid scenarios, Microsoft-centric orgs
- Key services: VMs, AKS, SQL Database, Blob Storage, Functions

### GCP (Google Cloud Platform)
- Kubernetes-native, strong ML/AI and data analytics
- Best for: Kubernetes-first, data processing, ML workloads
- Key services: Compute Engine, GKE, Cloud SQL, Cloud Storage, Cloud Run

## Architecture Frameworks

### AWS Well-Architected Framework

1. **Operational Excellence** -- IaC, CI/CD automation, observability
2. **Security** -- IAM least privilege, encryption, network segmentation
3. **Reliability** -- Multi-AZ, auto scaling, backup and DR
4. **Performance Efficiency** -- right-sizing, caching, CDN
5. **Cost Optimization** -- reserved/spot instances, auto scaling, tagging
6. **Sustainability** -- region selection, right-sizing to minimize waste

For AWS Terraform patterns (VPC, compute, storage, databases, cost optimization), see [terraform.md](terraform.md).

### GCP Architecture Framework

1. **System Design** -- microservices vs monolith, managed services, API design
2. **Operational Excellence** -- IaC, CI/CD, Cloud Operations Suite, SRE practices
3. **Security, Privacy, Compliance** -- IAM, VPC Service Controls, Binary Authorization, DLP
4. **Reliability** -- multi-region, auto scaling, Cloud Spanner for global consistency
5. **Cost Optimization** -- committed use discounts, spot VMs, active assist, billing budgets
6. **Performance Optimization** -- CDN, caching, right-sizing, Cloud Trace profiling

For GCP Terraform patterns (VPC, GKE, Cloud SQL, Cloud Run, IAM, cost), see [gcp.md](gcp.md).

## Azure Terraform Patterns

### AKS Cluster

```hcl
resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.name_prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.name_prefix

  default_node_pool {
    name            = "default"
    node_count      = 3
    vm_size         = "Standard_D2s_v3"
    os_disk_size_gb = 100
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }

  tags = local.common_tags
}
```

### Azure Functions

```hcl
resource "azurerm_linux_function_app" "this" {
  name                = "${var.name_prefix}-func"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.func.name
  storage_account_access_key = azurerm_storage_account.func.primary_access_key
  service_plan_id            = azurerm_service_plan.func.id

  site_config {
    application_stack {
      node_version = "20"
    }
  }

  tags = local.common_tags
}
```

## Multi-Cloud Strategy

### When Multi-Cloud Makes Sense
- Avoiding vendor lock-in for critical workloads
- Leveraging best-of-breed services across providers
- Geographic/regulatory requirements
- Disaster recovery across providers

### When to Avoid Multi-Cloud
- Increased operational complexity
- Higher costs (data transfer, tooling, training)
- Different APIs and provider-specific quirks

### Multi-Cloud Tooling
- **Terraform** -- unified IaC across all providers
- **Kubernetes** -- consistent compute abstraction layer
- **OpenTelemetry** -- vendor-neutral observability
- **Service mesh (Istio/Linkerd)** -- unified networking

## Disaster Recovery

### RTO/RPO Targets
- **RTO (Recovery Time Objective)**: maximum acceptable downtime
- **RPO (Recovery Point Objective)**: maximum acceptable data loss

### DR Strategies (ascending cost)

| Strategy | RPO | RTO | Cost |
|---|---|---|---|
| Backup & Restore | Hours | Hours | Low |
| Pilot Light | Minutes | Hours | Medium |
| Warm Standby | Seconds | Minutes | High |
| Active/Active | Near-zero | Near-zero | Highest |

### Multi-Region Setup (AWS)

```hcl
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

module "vpc_primary" {
  source    = "./modules/networking"
  providers = { aws = aws.primary }
}

module "vpc_dr" {
  source    = "./modules/networking"
  providers = { aws = aws.dr }
}

resource "aws_route53_health_check" "primary" {
  fqdn              = aws_lb.primary.dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = "3"
  request_interval  = "30"
}

resource "aws_route53_record" "app" {
  zone_id        = aws_route53_zone.main.id
  name           = "app.example.com"
  type           = "A"
  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.primary.id
}
```

### Multi-Region Setup (GCP)

```hcl
resource "google_compute_health_check" "primary" {
  name               = "${var.name_prefix}-health-check"
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = 443
    request_path = "/health"
  }
}

resource "google_compute_backend_service" "primary" {
  name                  = "${var.name_prefix}-backend"
  protocol              = "HTTPS"
  health_checks         = [google_compute_health_check.primary.id]
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_region_network_endpoint_group.primary.id
  }

  backend {
    group    = google_compute_region_network_endpoint_group.dr.id
    failover = true
  }
}

resource "google_dns_record_set" "app" {
  name         = "app.example.com."
  managed_zone = google_dns_managed_zone.this.name
  type         = "A"
  ttl          = 60

  routing_policy {
    wrr {
      weight  = 1.0
      rrdatas = [google_compute_global_address.primary.address]
    }
  }
}
```

For full GCP failover, use Global External Application Load Balancer with multi-region backend services. Cloud DNS supports geolocation and weighted routing policies for traffic distribution.

## Per-Cloud Best Practices

### AWS
- Use IAM roles, not access keys
- Enable CloudTrail in all regions
- Encrypt everything (S3, EBS, RDS)
- Use VPC for network isolation
- Tag all resources for cost allocation

### Azure
- Use Managed Identities
- Enable Azure Policy for governance
- Use Azure Key Vault for secrets
- Implement RBAC at resource group level
- Use Resource Groups for organization

### GCP
- Use Service Accounts with least privilege
- Enable Cloud Audit Logs
- Use VPC Service Controls for data perimeters
- Implement Organization Policies
- Use Labels for resource management and cost allocation

## Cloud Service Comparison

| Service Type | AWS | Azure | GCP |
|---|---|---|---|
| Compute | EC2 | Virtual Machines | Compute Engine |
| Containers | ECS, EKS | AKS | GKE |
| Serverless | Lambda | Functions | Cloud Functions, Cloud Run |
| Storage | S3 | Blob Storage | Cloud Storage |
| Database (SQL) | RDS | SQL Database | Cloud SQL |
| Database (NoSQL) | DynamoDB | Cosmos DB | Firestore, Bigtable |
| Networking | VPC | Virtual Network | VPC |
| Load Balancer | ALB/NLB | App Gateway | Cloud Load Balancing |
| CDN | CloudFront | Front Door | Cloud CDN |
| IAM | IAM | Entra ID | Cloud IAM |
| DNS | Route 53 | Azure DNS | Cloud DNS |
| Secret Manager | Secrets Manager | Key Vault | Secret Manager |
| Container Registry | ECR | ACR | Artifact Registry |
| CI/CD | CodePipeline | Azure DevOps | Cloud Build |
