# GCP Terraform Patterns

## GCP Organization Structure

```
Organization (example.com)
  Folders/
    Production/
      project-prod-app
      project-prod-data
    Staging/
      project-staging-app
    Shared/
      project-shared-networking
      project-shared-monitoring
```

Use folders to group projects by environment or team. Apply Organization Policies at the folder level. Each project gets its own billing, IAM, and API surface.

## GCS Backend for State

```hcl
terraform {
  backend "gcs" {
    bucket = "company-terraform-state"
    prefix = "infra"
  }
}
```

GCS appends the workspace name to the prefix automatically. Native object locking prevents concurrent writes -- no separate lock table needed.

```bash
# Create the bucket
gsutil mb -l us-central1 -b on gs://company-terraform-state
gsutil versioning set on gs://company-terraform-state
```

## Provider Configuration

```hcl
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

## VPC Networking

### VPC with Subnets and Cloud NAT

```hcl
resource "google_compute_network" "this" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "private" {
  name                     = "${var.name_prefix}-private"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

### Firewall Rules

```hcl
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name_prefix}-allow-internal"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.private_subnet_cidr]
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.name_prefix}-allow-health-check"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-health-check"]
}
```

## GKE

### Private Cluster with Workload Identity

```hcl
resource "google_container_cluster" "this" {
  name     = "${var.name_prefix}-gke"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.this.name
  subnetwork = google_compute_subnetwork.private.name

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  maintenance_policy {
    recurring_window {
      start_time = "2025-01-01T04:00:00Z"
      end_time   = "2025-01-01T08:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_network
      display_name = "authorized-network"
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }
}

resource "google_container_node_pool" "general" {
  name     = "general"
  location = var.region
  cluster  = google_container_cluster.this.name

  initial_node_count = var.node_count

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 100
    disk_type       = "pd-ssd"
    service_account = google_service_account.gke_node.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      environment = local.environment
      node_pool   = "general"
    }
  }
}

resource "google_container_node_pool" "spot" {
  name     = "spot"
  location = var.region
  cluster  = google_container_cluster.this.name

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = var.spot_max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    spot            = true
    machine_type    = var.machine_type
    disk_size_gb    = 100
    service_account = google_service_account.gke_node.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    taint {
      key    = "spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      environment = local.environment
      node_pool   = "spot"
    }
  }
}
```

## Cloud SQL

### PostgreSQL with Private IP and HA

```hcl
resource "google_compute_global_address" "sql_private" {
  name          = "${var.name_prefix}-sql-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "sql_private" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_private.name]
}

resource "google_sql_database_instance" "this" {
  name             = "${var.name_prefix}-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_size         = var.db_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.this.id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 14
      }
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }
  }

  deletion_protection = var.environment == "prod"

  depends_on = [google_service_networking_connection.sql_private]
}

resource "google_sql_database" "this" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "this" {
  name     = var.database_user
  instance = google_sql_database_instance.this.name
  password = random_password.db.result
}
```

## Cloud Run

```hcl
resource "google_cloud_run_v2_service" "this" {
  name     = "${var.name_prefix}-api"
  location = var.region

  template {
    scaling {
      min_instance_count = var.environment == "prod" ? 2 : 0
      max_instance_count = var.max_instances
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.name_prefix}/api:${var.image_tag}"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }

      env {
        name  = "ENV"
        value = local.environment
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/healthz"
        }
        period_seconds = 30
      }
    }

    service_account = google_service_account.cloud_run.email

    vpc_access {
      connector = google_vpc_access_connector.this.id
      egress    = "PRIVATE_RANGES_ONLY"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_public_access ? 1 : 0

  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

## Cloud Storage

```hcl
resource "google_storage_bucket" "data" {
  name                        = "${var.project_id}-${var.name_prefix}-data"
  location                    = var.region
  force_destroy               = var.environment != "prod"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.storage.id
  }

  labels = {
    environment = local.environment
    managed_by  = "terraform"
  }
}
```

## IAM

### Service Accounts and Workload Identity

```hcl
resource "google_service_account" "gke_node" {
  account_id   = "${var.name_prefix}-gke-node"
  display_name = "GKE Node Service Account"
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_service_account" "app" {
  account_id   = "${var.name_prefix}-app"
  display_name = "Application Service Account"
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}

resource "google_project_iam_member" "app_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_project_iam_member" "app_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}
```

## Secret Manager

```hcl
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.name_prefix}-db-password"

  replication {
    auto {}
  }

  labels = {
    environment = local.environment
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

resource "random_password" "db" {
  length  = 32
  special = true
}
```

## Cost Optimization

### Budget Alerts

```hcl
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "${var.name_prefix}-monthly-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.monthly_budget
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = var.notification_channels
  }
}
```

### Cost Tips
- Use Spot VMs for fault-tolerant workloads (60-91% discount)
- Use Committed Use Discounts for predictable workloads (1-3 year commitment)
- Enable auto-scaling on GKE node pools to scale to zero during off-peak
- Use lifecycle rules on Cloud Storage to move data to cheaper tiers
- Set resource quotas per project to prevent runaway spending
- Use E2 or N2D machine types for cost-effective general workloads

## Enabling APIs

```hcl
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "vpcaccess.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
```

## gcloud Commands Cheat Sheet

```bash
# Authentication
gcloud auth login
gcloud auth application-default login
gcloud config set project PROJECT_ID

# GKE
gcloud container clusters get-credentials CLUSTER --region REGION
gcloud container clusters list
gcloud container node-pools list --cluster CLUSTER --region REGION

# Cloud SQL
gcloud sql instances list
gcloud sql connect INSTANCE --user=USER --database=DB

# Cloud Run
gcloud run services list
gcloud run deploy SERVICE --image IMAGE --region REGION
gcloud run services update-traffic SERVICE --to-revisions=LATEST=100

# IAM
gcloud iam service-accounts list
gcloud projects get-iam-policy PROJECT_ID --format=json
gcloud iam service-accounts keys create key.json --iam-account SA_EMAIL

# Networking
gcloud compute networks list
gcloud compute firewall-rules list
gcloud compute addresses list

# Secret Manager
gcloud secrets list
gcloud secrets versions access latest --secret=SECRET_NAME

# Billing
gcloud billing accounts list
gcloud billing projects describe PROJECT_ID
```

---

## Resources
- [Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Terraform Modules](https://github.com/terraform-google-modules)
- [GCP Architecture Framework](https://cloud.google.com/architecture/framework)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
