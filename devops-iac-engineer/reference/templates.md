# Ready-to-Use DevOps Templates

## Terraform Templates

### AWS EKS Cluster

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.name_prefix}-cluster"
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    general = {
      min_size     = 2
      max_size     = 10
      desired_size = 3

      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }
    }

    spot = {
      min_size     = 0
      max_size     = 10
      desired_size = 2

      instance_types = ["t3.large", "t3a.large"]
      capacity_type  = "SPOT"

      labels = {
        role = "spot"
      }

      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NoSchedule"
      }]
    }
  }

  tags = var.tags
}
```

### AWS RDS PostgreSQL

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-subnet-group"
    }
  )
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${var.name_prefix}-postgres-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  tags = var.tags
}

resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.database_name
  username = var.master_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  deletion_protection   = var.environment == "prod" ? true : false
  skip_final_snapshot   = var.environment != "prod" ? true : false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db"
    }
  )
}
```

## CI/CD Templates

### GitHub Actions -- Terraform Workflow

```yaml
name: Terraform

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'

env:
  TF_VERSION: 1.6.0
  AWS_REGION: us-east-1

jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest

    permissions:
      id-token: write
      contents: read
      pull-requests: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: ./terraform

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Validate
        run: terraform validate
        working-directory: ./terraform

      - name: Terraform Plan
        id: plan
        run: |
          terraform workspace select prod
          terraform plan -var-file=envs/prod.tfvars -no-color -out=tfplan
        working-directory: ./terraform
        continue-on-error: true

      - name: Post Plan to PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan

            <details><summary>Show Plan</summary>

            \`\`\`terraform
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            </details>`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
        working-directory: ./terraform
```

### GCP GKE Cluster

```hcl
module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 30.0"

  project_id = var.project_id
  name       = "${var.name_prefix}-gke"
  region     = var.region
  network    = module.vpc.network_name
  subnetwork = module.vpc.subnets_names[0]

  ip_range_pods     = "pods"
  ip_range_services = "services"

  enable_private_endpoint = false
  enable_private_nodes    = true
  master_ipv4_cidr_block  = "172.16.0.0/28"

  identity_namespace = "${var.project_id}.svc.id.goog"

  node_pools = [
    {
      name           = "general"
      machine_type   = "e2-standard-4"
      min_count      = 1
      max_count      = 10
      disk_size_gb   = 100
      disk_type      = "pd-ssd"
      auto_repair    = true
      auto_upgrade   = true
      spot           = false
    },
    {
      name           = "spot"
      machine_type   = "e2-standard-4"
      min_count      = 0
      max_count      = 10
      disk_size_gb   = 100
      spot           = true
      auto_repair    = true
      auto_upgrade   = true
    },
  ]

  node_pools_labels = {
    all     = { environment = local.environment }
    general = { node_pool = "general" }
    spot    = { node_pool = "spot" }
  }

  node_pools_taints = {
    spot = [{ key = "spot", value = "true", effect = "NO_SCHEDULE" }]
  }
}
```

### GCP Cloud SQL PostgreSQL

```hcl
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

      backup_retention_settings {
        retained_backups = 14
      }
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
    }
  }

  deletion_protection = var.environment == "prod"

  depends_on = [google_service_networking_connection.sql_private]
}
```

## Docker Templates

### .dockerignore

```
.git
.gitignore
.gitattributes
.github
.gitlab-ci.yml
Jenkinsfile
README.md
docs/
*.md
node_modules
npm-debug.log
coverage/
.nyc_output
test/
*.test.js
.vscode
.idea
*.swp
*.swo
.DS_Store
Thumbs.db
.env
.env.*
!.env.example
dist/
build/
*.log
```

## Makefile Template

```makefile
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: tf-init
tf-init: ## Initialize Terraform
	cd terraform && terraform init

.PHONY: tf-plan
tf-plan: ## Plan Terraform changes (usage: make tf-plan ENV=dev)
	cd terraform && terraform workspace select $(ENV) && terraform plan -var-file=envs/$(ENV).tfvars -out=tfplan

.PHONY: tf-apply
tf-apply: ## Apply Terraform changes
	cd terraform && terraform apply tfplan

.PHONY: k8s-apply
k8s-apply: ## Apply Kubernetes manifests
	kubectl apply -f kubernetes/ -n $(NAMESPACE)

.PHONY: k8s-delete
k8s-delete: ## Delete Kubernetes resources
	kubectl delete -f kubernetes/ -n $(NAMESPACE)

.PHONY: docker-build
docker-build: ## Build Docker image
	docker build -t $(IMAGE_NAME):$(TAG) .

.PHONY: docker-push
docker-push: ## Push Docker image
	docker push $(IMAGE_NAME):$(TAG)

.PHONY: lint
lint: ## Run linters
	terraform fmt -check -recursive
	kubeval --strict kubernetes/*.yaml

.PHONY: test
test: ## Run tests
	go test ./... -v -cover

.PHONY: clean
clean: ## Clean build artifacts
	rm -rf dist/ build/ *.log
```

## Monitoring Templates

### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp
  namespace: production
  labels:
    app: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```
