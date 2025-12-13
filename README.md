# Microservices .NET Template

An opinionated .NET 9 boilerplate for API-first microservices (User, Guest) with an API Gateway, Redis, RabbitMQ, PostgreSQL, and optional n8n automation. Infrastructure is codified with Terraform so you can deploy either to AWS ECS/Fargate or to AWS EKS with Kubernetes manifests.

## Quickstart (fresh clone)
1. Clone: `git clone https://github.com/VKev/Microservices-Dot-Net-Template.git && cd Microservices-Dot-Net-Template`.
2. Create private tfvars: copy files from `Terraform-vars/` to `terraform-var/` (same names) and fill real values (AWS account ID in ECR URLs, DB passwords, Cloudflare/CloudFront settings, etc.). Keep `terraform-var/` uncommitted.
3. Choose platform:
   - ECS/Fargate: set `use_eks = false` in `terraform-var/common.auto.tfvars`.
   - EKS: set `use_eks = true` and keep `k8s.auto.tfvars` in sync; secrets live only in `terraform-var/k8s.auto.tfvars` while `Terraform-vars/k8s.auto.tfvars` stays redacted.
4. Local smoke test: `docker compose up -d --build` then call services on 5001/5002/8080.
5. Terraform deploy (example):
   ```powershell
   terraform -chdir=Terraform init
   terraform -chdir=Terraform apply `
     -var-file=../terraform-var/common.auto.tfvars `
     -var-file=../terraform-var/k8s.auto.tfvars `
     -var-file=../terraform-var/guest-service.auto.tfvars `
     -var-file=../terraform-var/user-service.auto.tfvars `
     -var-file=../terraform-var/apigateway-service.auto.tfvars `
     -var-file=../terraform-var/rabbitmq-service.auto.tfvars `
     -var-file=../terraform-var/redis-service.auto.tfvars
   ```
   Omit `k8s.auto.tfvars` when deploying ECS-only.

## Stack
- .NET 9 WebAPI services: User, Guest, API Gateway (reverse proxy/aggregator)
- Data plane: PostgreSQL, Redis, RabbitMQ
- Optional: n8n + nginx sidecar, service discovery via ECS Service Connect
- AWS: VPC, ALB/CloudFront/Cloudflare, ECR, RDS, ECS/Fargate, EKS
- Tooling: Docker/Compose, Terraform, GitHub Actions

## Repository Layout
- `Backend/` - microservice source (Application/Domain/Infrastructure/WebApi for each service).
- `docker-compose-production.yml` - sample compose to run the stack locally (DB, Redis, RabbitMQ, services).
- `Terraform/` - Terraform root, modules, and helper scripts.
- `Terraform-vars/` - sanitized tfvars templates (redacted secrets) used for CI/reference.

## Prerequisites
- .NET 9 SDK
- Docker and Docker Compose
- Terraform >= 1.6
- AWS CLI configured with an account that can create VPC/ECR/RDS/ALB/ECS/EKS
- Python 3 (for helper scripts in `Terraform/scripts`)

## Local Development
1. Restore and build: `dotnet restore` then `dotnet build` from repo root.
2. Run tests: `dotnet test`.
3. Start local dependencies/services: `docker compose -f docker-compose.yml up -d --build`.
4. Run a service: `dotnet run --project Backend/Microservices/User.Microservice/src/WebApi/WebApi.csproj` (repeat for others).
5. Apply EF Core migrations (example, replace placeholders):
   ```powershell
   $env:ASPNETCORE_ENVIRONMENT="Development"; dotnet ef migrations add Initial `
     -p Backend/Microservices/User.Microservice/src/Infrastructure/Infrastructure.csproj `
     -s Backend/Microservices/User.Microservice/src/Infrastructure/Infrastructure.csproj `
     -c MyDbContext --msbuildprojectextensionspath Backend/Microservices/User.Microservice/src/Infrastructure/Build/obj `
     -- --connection-string="Host=<db-host>;Port=<port>;Database=<db>;Username=<user>;Password=<password>;SslMode=Require"
   ```
   Run `dotnet ef database update` with the same args to apply the migration.

## Infrastructure (AWS)
### tfvars model
- Authoritative secrets live in `terraform-var/*.auto.tfvars` (keep private).
- Redacted templates live in `Terraform-vars/*.auto.tfvars` for sharing/CI.
- Toggle platform with `use_eks` in `common.auto.tfvars`:
  - `true` -> provision EKS and apply `k8s_microservices_manifest` from `k8s.auto.tfvars`.
  - `false` -> deploy microservices to ECS/Fargate with ALB + Service Connect.
- When using EKS, keep the manifest structure identical to `terraform-var/k8s.auto.tfvars` but replace secrets with placeholders in the sanitized copy.

### Deploy with Terraform CLI
```powershell
# from repo root
terraform -chdir=Terraform init
terraform -chdir=Terraform plan `
  -var-file=../terraform-var/common.auto.tfvars `
  -var-file=../terraform-var/k8s.auto.tfvars `
  -var-file=../terraform-var/guest-service.auto.tfvars `
  -var-file=../terraform-var/user-service.auto.tfvars `
  -var-file=../terraform-var/apigateway-service.auto.tfvars `
  -var-file=../terraform-var/rabbitmq-service.auto.tfvars `
  -var-file=../terraform-var/redis-service.auto.tfvars
terraform -chdir=Terraform apply <same var-files>
```
- For ECS-only deployments set `use_eks = false` and omit `k8s.auto.tfvars`.
- Destroy with the same var files: `terraform -chdir=Terraform destroy ...`.

### GitHub Actions (CI/CD)
- Workflows:
  - `Full Infrastructure Deploy`: builds and pushes images to ECR, merges tfvars from environment secrets, runs Terraform plan/apply/destroy.
  - `Deploy Infrastructure with Terraform`: Terraform plan/apply/destroy only (no image build).
  - `Build and Push Microservices to ECR`: builds all microservice images and pushes to AWS ECR.
  - `Build and Push Microservices to Docker Hub`: builds/pushes to Docker Hub (optional alt registry).
  - `Bootstrap Terraform Backend`: creates the S3/DynamoDB backend for Terraform state/locks.
  - `Request ACM Certificate (Cloudflare DNS)`: provisions ACM cert via Cloudflare DNS-01.
  - `Nuke ECR Repositories`: deletes ECR repositories (cleanup).
  - `Nuke AWS (except ECR)`: tears down AWS resources except ECR (safety valve).
- Environment vars: `AWS_REGION`, `PROJECT_NAME`.
- Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, plus tfvars payloads (e.g., `TERRAFORM_VARS_COMMON`, `TERRAFORM_VARS_K8S`, `TERRAFORM_VARS_GUEST`, `TERRAFORM_VARS_USER`, `TERRAFORM_VARS_APIGATEWAY`, `TERRAFORM_VARS_REDIS`, `TERRAFORM_VARS_RABBITMQ`, `TERRAFORM_VARS_N8N`, `TERRAFORM_VARS_NGINX`, `TERRAFORM_VARS_ECS_GROUPS`). Paste contents from your private `terraform-var` files.

### GitHub Environment setup (step-by-step)
1. Settings -> Environments -> New environment (e.g., `infrastructure-prod`).
2. Add environment variables: `AWS_REGION`, `PROJECT_NAME`.
3. Add environment secrets:
   - AWS creds: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
   - Terraform tfvars payloads: create secrets named above (COMMON, K8S, GUEST, USER, APIGATEWAY, REDIS, RABBITMQ, N8N, NGINX, ECS_GROUPS as needed). Paste the full contents of each matching file from your private `terraform-var/`.
4. Run the workflow: Actions -> `Full Infrastructure Deploy` -> Run workflow -> select your environment -> choose `plan` or `apply`.

### What gets deployed (platform toggle)
- `use_eks = true` (default): provisions an EKS cluster (t3.small nodes, desired=4 by default) and applies the `k8s_microservices_manifest` to namespace `microservices`. Workloads: Redis (+ PVC + Secret), RabbitMQ (+ PVC + Secret), n8n, nginx proxy for n8n, Guest microservice, User microservice, API Gateway, plus their services/NodePorts.
- `use_eks = false`: provisions ECS on EC2 with 3 container instances (server-1/2/3). Task groups: server-1 runs redis + rabbitmq + user with host-path data volumes; server-2 runs guest + apigateway; server-3 runs n8n + nginx proxy. Uses ALB and Service Connect for traffic and discovery.


## Cleanup
- Local: `docker compose down -v`.
- Cloud: `terraform -chdir=Terraform destroy` with the same var files used for apply.
