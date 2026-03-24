# Terraform Best Practices & Patterns

## Project Structure -- DRY with Workspaces

Use a single set of configuration files parameterized by workspace and variable files. Do not duplicate `.tf` files across environments.

```
terraform/
  modules/
    networking/
      main.tf
      variables.tf
      outputs.tf
    compute/
    database/
  envs/
    dev.tfvars
    staging.tfvars
    prod.tfvars
  main.tf
  variables.tf
  outputs.tf
  versions.tf
  backend.tf
```

### File Responsibilities

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and provider version constraints |
| `backend.tf` | Remote state backend configuration |
| `main.tf` | Module calls, locals, data sources |
| `variables.tf` | Variable declarations |
| `outputs.tf` | Output declarations |
| `envs/*.tfvars` | Per-environment variable values |

### Workspace Workflow

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace select dev
terraform plan -var-file=envs/dev.tfvars -out=tfplan
terraform apply tfplan
```

Never use `terraform.tfvars` -- it auto-loads and creates ambiguity. Always use named var files with `-var-file`.

### versions.tf

```hcl
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
```

### Environment-Aware Configuration

```hcl
locals {
  environment = terraform.workspace

  common_tags = {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
    Owner       = var.owner
  }
}
```

## Naming Conventions

Follow [terraform-best-practices.com](https://www.terraform-best-practices.com/naming) naming rules:

1. Use `_` (underscore) not `-` (dash) in all Terraform names (resources, variables, outputs, data sources)
2. Do not repeat the resource type in the resource name:

```hcl
# Good
resource "aws_route_table" "public" {}

# Bad -- redundant type in name
resource "aws_route_table" "public_route_table" {}
```

3. Name a resource `this` when a module creates only one of that type:

```hcl
resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0
  # ...
}
```

4. Place `count`/`for_each` as the first argument. Place `tags` last, before `depends_on` and `lifecycle`:

```hcl
resource "aws_subnet" "public" {
  for_each = toset(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.value))
  availability_zone = each.value

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-${each.value}"
  })
}
```

5. Use singular nouns for resource names.
6. Always include `description` on all variables and outputs.
7. Order variable keys: `description`, `type`, `default`, `validation`.
8. Use plural names for variables of type `list(...)` or `map(...)`.

## State Management

### Remote State with Workspace Support

Workspaces automatically namespace the state key, so a single backend config serves all environments.

**AWS S3 Backend:**

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**GCP GCS Backend:**

```hcl
terraform {
  backend "gcs" {
    bucket = "company-terraform-state"
    prefix = "infra"
  }
}
```

Both backends append the workspace name to the key automatically.

### State Locking Setup (AWS)

```bash
aws s3api create-bucket \
  --bucket company-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket company-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket company-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### State Locking Setup (GCP)

```bash
gsutil mb -l us-central1 gs://company-terraform-state
gsutil versioning set on gs://company-terraform-state
```

GCS uses native object locking -- no separate lock table needed.

## Module Development (AWS VPC Example)

### modules/networking/main.tf

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  for_each = toset(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.value))
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${each.value}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = toset(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.value) + length(var.availability_zones))
  availability_zone = each.value

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${each.value}"
    Tier = "private"
  })
}

resource "aws_internet_gateway" "this" {
  count = var.create_public_subnets ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_eip" "nat" {
  for_each = var.create_nat_gateway ? toset(var.single_nat_gateway ? [var.availability_zones[0]] : var.availability_zones) : toset([])

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${each.value}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = aws_eip.nat

  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}
```

### modules/networking/variables.tf

```hcl
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "create_public_subnets" {
  description = "Whether to create public subnets"
  type        = bool
  default     = true
}

variable "create_nat_gateway" {
  description = "Whether to create NAT gateways for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs (cost optimization)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### modules/networking/outputs.tf

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [for s in aws_subnet.private : s.id]
}

output "nat_gateway_ids" {
  description = "IDs of NAT gateways"
  value       = [for n in aws_nat_gateway.this : n.id]
}
```

## Advanced Patterns

### Data Sources for Dynamic Configuration

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}
```

### Dynamic Blocks

```hcl
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app"
  description = "Application security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}
```

### Conditional Resource Creation

```hcl
resource "aws_db_instance" "replica" {
  count = var.environment == "prod" ? var.replica_count : 0

  identifier          = "${var.name_prefix}-replica-${count.index + 1}"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.replica_instance_class
  publicly_accessible = false
  skip_final_snapshot = true

  tags = local.common_tags
}
```

### Lifecycle Management

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  tags = local.common_tags

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
    ignore_changes        = [ami, tags["LastModified"]]
  }
}
```

## Security Best Practices

### Never Hardcode Credentials

```hcl
# BAD
resource "aws_db_instance" "bad" {
  username = "admin"
  password = "SuperSecret123!"
}

# GOOD -- use a secret manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/master-password"
}

resource "aws_db_instance" "this" {
  username = "admin"
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}

# BETTER -- generate and store
resource "random_password" "db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.name_prefix}-db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}
```

### Encryption

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${var.name_prefix}-data"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
```

## Cost Optimization

### Spot Instances with Mixed ASG

```hcl
resource "aws_autoscaling_group" "app" {
  name                = "${var.name_prefix}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 20
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.app.id
        version            = "$Latest"
      }

      override {
        instance_type = "t3.medium"
      }
      override {
        instance_type = "t3a.medium"
      }
    }
  }

  tag {
    key                 = "Environment"
    value               = local.environment
    propagate_at_launch = true
  }
}
```

## Testing and Validation

### Input Validation

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.77.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
      - id: terraform_checkov
```

### CI Validation

```yaml
name: Terraform CI
on:
  pull_request:
    paths: ['terraform/**']

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0
      - run: terraform fmt -check -recursive
      - run: terraform init -backend=false
        working-directory: ./terraform
      - run: terraform validate
        working-directory: ./terraform
      - uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform
```

## Anti-Patterns

### Don't: Duplicate configs across environments
Use workspaces + var files. A full `environments/dev/`, `environments/staging/`, `environments/prod/` directory tree with copied `.tf` files drifts over time and violates DRY.

### Don't: Manage state manually
Never edit `.tfstate` directly. Never commit state to Git. Always use remote state with locking.

### Don't: Use count for stateful resources

```hcl
# Bad -- reordering the list recreates resources
resource "aws_instance" "web" {
  count = length(var.instance_names)
}

# Good -- stable addressing by key
resource "aws_instance" "web" {
  for_each = toset(var.instance_names)
}
```

### Don't: Create monolithic configurations
Split into modules by concern (networking, compute, data). Use module composition.

### Don't: Ignore drift

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions != ["no-op"])'
```

## Commands Cheat Sheet

```bash
terraform init                    # Initialize providers
terraform init -upgrade           # Upgrade providers
terraform fmt -recursive          # Format all files
terraform validate                # Validate config
terraform plan -var-file=envs/dev.tfvars -out=tfplan
terraform apply tfplan
terraform destroy

terraform workspace new prod
terraform workspace select prod
terraform workspace list

terraform import aws_instance.example i-1234567890abcdef0
terraform state list
terraform state rm aws_instance.example
terraform output
```

## Advanced Topics

### Terraform Cloud/Enterprise
- Remote execution and state management
- Policy as code with Sentinel
- Private module registry
- Cost estimation and VCS integration

### Dependency Management

```hcl
# Implicit -- Terraform detects from attribute references
resource "aws_instance" "web" {
  subnet_id = aws_subnet.public["us-east-1a"].id
}

# Explicit -- when no attribute reference exists
resource "aws_instance" "web" {
  # ...
  depends_on = [aws_iam_role_policy_attachment.this]
}
```

---

## Resources
- [Terraform Registry](https://registry.terraform.io/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
