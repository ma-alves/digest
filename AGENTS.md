# AGENTS.md

## Project Overview

DON'T COMMIT WITHOUT MY PERMISSION
DON'T TEST WITHOUT MY PERMISSION
DON'T DELETE OR UPDATE THE TWO LINES ABOVE

**Digest** is a serverless automated newsletter application built with TypeScript and AWS CDK that:
- Calls NewsAPI to fetch articles based on configured search criteria
- Extracts relevant articles from the API response
- Renders articles into a Handlebars email template
- Sends newsletters to subscribers via SES in batches of 50
- All orchestrated by a Step Functions workflow triggered daily by EventBridge

**Tech Highlights:**
- TypeScript + Node.js 20 Lambda functions (8 handlers)
- AWS Step Functions for newsletter workflow orchestration
- API Gateway for subscriber CRUD endpoints
- DynamoDB for persistence (subscribers + newsletters with GSIs)
- S3 for template storage and rendered HTML
- CDK (TypeScript) for infrastructure-as-code
- SES for email delivery, SNS for failure notifications

## Commands
- Build/Lint: `npm run lint` (tsc --noEmit)
- Run tests: `npm test` (only when explicitly requested)
- Watch tests: `npm run test:watch`
- CDK synth: `npm run cdk:synth`
- CDK diff: `npm run cdk:diff`
- CDK deploy all: `npm run cdk:deploy`
- CDK deploy single stack: `npx cdk deploy <StackName>`
- Seed subscribers: `npm run seed`

> **Note:** Do not run tests unless explicitly requested by the user.

## Development Setup

```bash
# 1. Install dependencies
npm ci

# 2. Create .env file with credentials
cp .env.example .env
# Edit .env with NEWSAPI_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

# 3. Bootstrap CDK (first time only)
npx cdk bootstrap

# 4. Deploy all stacks
npm run cdk:deploy
```

## Project Structure

```
digest/
├── cdk/                        # CDK infrastructure
│   ├── bin/app.ts              # Entry point
│   ├── stacks/                 # DatabaseStack, ApiStack, NewsletterStack, etc.
│   └── config.ts               # Deployment config
├── lambdas/
│   ├── shared/                 # Lambda Layer (models, DynamoDB client, Zod schemas, utils)
│   ├── subscribe-handler/      # POST /api/v1/subscribers
│   ├── list-subscribers/       # GET /api/v1/subscribers
│   ├── unsubscribe-handler/    # GET /unsubscribe?email=
│   ├── fetch-articles/         # NewsAPI caller (workflow step)
│   ├── generate-newsletter/    # Handlebars rendering (workflow step)
│   ├── send-emails/            # SES batching (workflow step)
│   ├── mark-newsletter-status/ # Update DynamoDB (workflow step)
│   └── notify-failure/         # SNS publish (workflow step)
├── scripts/                    # Seed scripts
├── package.json
├── tsconfig.json
└── jest.config.ts
```

## Architecture

- **EventBridge Scheduler** triggers the Step Functions workflow daily at 08:00 UTC
- **Step Functions** orchestrates 5 Lambda tasks: fetch-articles → generate-newsletter → send-emails → mark-sent/failed
- **API Gateway** (REST) exposes 3 endpoints: POST/GET `/api/v1/subscribers`, GET `/unsubscribe`
- **DynamoDB** has 2 tables: `subscribers` (PK: email) and `newsletters` (PK: id, GSI on status)
- **S3** stores the Handlebars template and rendered HTML newsletters
- **Secrets Manager** holds the NewsAPI key; **SNS** notifies admins on failure

## Tech Stack

- TypeScript, Node.js 20, AWS CDK v2
- Lambda, API Gateway, Step Functions, EventBridge
- DynamoDB, S3, SES, SNS, Secrets Manager, CloudWatch
- Handlebars, Zod, Axios, ULID, esbuild

## Deployment

### CI/CD (GitHub Actions)

On push to `main`: `npm ci` → `npm test` → `cdk deploy --all --require-approval never`
