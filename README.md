# Digest

Digest is a serverless automated newsletter application built with TypeScript and AWS. It fetches articles from NewsAPI, generates HTML newsletters using Handlebars templates, and sends them to subscribers via SES — all orchestrated by a Step Functions workflow triggered daily by EventBridge.

## Architecture

- **EventBridge Scheduler** triggers the workflow daily at 08:00 UTC
- **Step Functions** orchestrates the newsletter pipeline (fetch → generate → send → mark → notify)
- **API Gateway** handles subscriber CRUD (POST/GET `/api/v1/subscribers`, GET `/unsubscribe`)
- **Lambda** (Node.js 24) provides all compute — 8 handlers
- **DynamoDB** stores subscribers and newsletters (2 tables, PAY_PER_REQUEST, GSI on newsletters)
- **S3** stores Handlebars templates and rendered HTML
- **SES** sends emails in batches of 50 with exponential backoff retry
- **Secrets Manager** stores the NewsAPI key
- **SNS** notifies admins on workflow failures
- **Terraform** (HCL) defines all infrastructure

## Tech Stack

- TypeScript, Node.js 24, Terraform (HCL)
- Lambda, API Gateway, Step Functions, EventBridge
- DynamoDB, S3, SES, SNS, Secrets Manager, CloudWatch
- Handlebars, Zod, Axios, ULID, esbuild

## Setup

```bash
git clone https://github.com/ma-alves/digest.git
cp .env.example .env
# edit .env with your credentials

# Bootstrap Terraform state backend (first time only)
bash scripts/bootstrap-state.sh

# Install deps + build Lambdas + deploy
npm ci
npm run build:handlers
npm run tf:apply
```

## Project Structure

```
digest/
├── terraform/                    # Terraform infrastructure
│   ├── main.tf                   # Provider, module wiring, IAM policies
│   ├── variables.tf              # Shared variables
│   ├── outputs.tf                # API URL, SNS ARN, etc.
│   ├── backend.tf                # S3 + DynamoDB state backend
│   ├── terraform.tfvars.example  # Example deploy-time values
│   ├── modules/
│   │   ├── database/             # DynamoDB tables + S3 buckets
│   │   ├── api/                  # API Gateway + routes
│   │   ├── lambda-function/      # Reusable Lambda + IAM role
│   │   ├── lambda-layer/         # Shared Lambda Layer
│   │   ├── workflow/             # Step Functions + EventBridge + SNS
│   │   └── monitoring/           # CloudWatch dashboard + alarms
│   └── lambda-packages/          # Pre-built ZIPs (gitignored)
├── handlers/                     # TypeScript Lambda handlers
│   ├── shared/                   # Lambda Layer (models, DynamoDB client, Zod schemas, utils)
│   ├── subscribe-handler/        # POST /api/v1/subscribers
│   ├── list-subscribers/         # GET /api/v1/subscribers
│   ├── unsubscribe-handler/      # GET /unsubscribe?email=
│   ├── fetch-articles/           # NewsAPI caller (workflow step)
│   ├── generate-newsletter/      # Handlebars rendering (workflow step)
│   ├── send-emails/              # SES batching (workflow step)
│   ├── mark-newsletter-status/   # Update DynamoDB (workflow step)
│   └── notify-failure/           # SNS publish (workflow step)
├── scripts/                      # Build + bootstrap + seed scripts
├── package.json
├── tsconfig.json
├── jest.config.cjs
└── .env.example
```

## CI/CD

GitHub Actions runs `build:handlers` → `npm test` → `terraform apply` on pushes to `main`.

## Testing

Unit tests with **Jest 30** + `aws-sdk-client-mock` covering all 8 Lambda handlers. Each test file mocks AWS SDK clients (DynamoDB, S3, SES, SNS, Secrets Manager) to test handler logic in isolation.

```bash
npm test        # Run all tests
npm run lint    # TypeScript type-check (tsc --noEmit)
npm run test:watch  # Watch mode
```

## Commands

| Command | Description |
|---------|-------------|
| `npm run build:handlers` | esbuild + zip all handlers + layer |
| `npm run lint` | TypeScript type-check |
| `npm test` | Run all Jest tests |
| `npm run test:watch` | Jest watch mode |
| `npm run tf:init` | Terraform init |
| `npm run tf:plan` | Terraform plan |
| `npm run tf:apply` | Terraform apply |
| `npm run tf:destroy` | Terraform destroy |
| `npm run seed` | Seed subscribers into DynamoDB |
