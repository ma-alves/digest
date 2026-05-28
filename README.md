# Digest

Digest is a serverless automated newsletter application built with TypeScript and AWS. It fetches articles from NewsAPI, generates HTML newsletters using Handlebars templates, and sends them to subscribers via SES — all orchestrated by a Step Functions workflow triggered daily by EventBridge.

## Architecture

- **EventBridge Scheduler** triggers the workflow daily at 08:00 UTC
- **Step Functions** orchestrates the newsletter pipeline (fetch → generate → send)
- **API Gateway** handles subscriber CRUD (POST/GET `/api/v1/subscribers`, GET `/unsubscribe`)
- **Lambda** (Node.js 20) provides all compute — 8 handlers
- **DynamoDB** stores subscribers and newsletters (2 tables, PAY_PER_REQUEST)
- **S3** stores Handlebars templates and rendered HTML
- **SES** sends emails in batches of 50 with exponential backoff retry
- **Secrets Manager** stores the NewsAPI key
- **SNS** notifies admins on workflow failures
- **CDK** (TypeScript) defines all infrastructure

## Tech Stack

- TypeScript, Node.js 20, AWS CDK
- Lambda, API Gateway, Step Functions, EventBridge
- DynamoDB, S3, SES, SNS, Secrets Manager, CloudWatch
- Handlebars, Zod, Axios, ULID

## Setup

```bash
git clone https://github.com/ma-alves/digest.git
cp .env.example .env
# edit .env with your credentials
npx cdk bootstrap
npm run cdk:deploy
```

## Project Structure

```
digest/
├── cdk/               # CDK stacks (Database, Api, Newsletter, Scheduler, etc.)
├── lambdas/
│   ├── shared/        # Lambda Layer (models, DynamoDB client, validators)
│   ├── subscribe-handler/
│   ├── list-subscribers/
│   ├── unsubscribe-handler/
│   ├── fetch-articles/
│   ├── generate-newsletter/
│   ├── send-emails/
│   ├── mark-newsletter-status/
│   └── notify-failure/
├── scripts/
├── package.json
└── tsconfig.json
```

## CI/CD

GitHub Actions runs tests and deploys all stacks via `cdk deploy --all` on pushes to `main`.

## Testing

Unit tests with Jest + `aws-sdk-client-mock`, infrastructure tests with CDK assertions.
