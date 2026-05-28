# Digest — TypeScript + AWS Serverless Migration Plan

## Architecture Overview

```
                        ┌──────────────────────┐
                        │  AWS Secrets Manager  │
                        │  newsapi-key          │
                        └──────────┬───────────┘
                                   │
┌──────────────────────┐           │
│  EventBridge          │           │
│  Scheduler            │           │
│  cron(0 8 * * ?)     │           │
└──────────┬───────────┘           │
           │                       │
           ▼                       ▼
┌────────────────────────────────────────────────┐
│  Step Functions: NewsletterWorkflow              │
│                                                  │
│  ┌──────────────┐    ┌──────────────────┐       │
│  │ Lambda:      │    │ Lambda:          │       │
│  │ fetch-articles│───▶│ generate-        │       │
│  │ NewsAPI call  │    │ newsletter       │       │
│  └──────┬───────┘    └────────┬─────────┘       │
│         │                     │                  │
│         ▼                     ▼                  │
│    NewsAPI              S3 Bucket                │
│    (external)           template.hbs             │
│                                                  │
│         ┌──────────────────┐                     │
│         │ Lambda:          │                     │
│         │ send-emails      │◀────────────────────┘
│         │ SES batch(50)    │
│         │ + retry          │
│         └────────┬─────────┘
│                  │
│         ┌────────┴─────────┐
│         │ Failure → SNS    │
│         │ Notify (admin)   │
│         └──────────────────┘
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│  API Gateway (REST)                             │
│                                                 │
│  POST /api/v1/subscribers                       │
│    → Lambda: subscribe-handler                  │
│      → DynamoDB subscribers table               │
│      → 201 Created / 409 Conflict               │
│                                                 │
│  GET /api/v1/subscribers                        │
│    → Lambda: list-subscribers                   │
│      → DynamoDB Scan                            │
│      → 200 OK                                   │
│                                                 │
│  GET /unsubscribe?email=user@example.com        │
│    → Lambda: unsubscribe-handler                │
│      → DynamoDB (status → UNSUBSCRIBED)         │
│      → 200 OK (landing page)                    │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│  DynamoDB (2 tables)                           │
│                                                 │
│  subscribers (PK: email)                        │
│  ├─ email        String  PK                     │
│  ├─ id           String  ULID                   │
│  ├─ createdAt    String  ISO8601                │
│  └─ status       String  ACTIVE/UNSUBSCRIBED    │
│                                                 │
│  newsletters (PK: id)                           │
│  ├─ id            String  PK (ULID)             │
│  ├─ title         String                        │
│  ├─ articleCount  Number                        │
│  ├─ status        String  GSI1-PK               │
│  ├─ generatedAt   String  GSI1-SK (ISO8601)     │
│  ├─ sentAt        String  nullable, ISO8601      │
│  ├─ htmlS3Key     String                        │
│  └─ errorMessage  String  nullable              │
└────────────────────────────────────────────────┘
```

---

## Project Structure

```
digest/
├── cdk/
│   ├── bin/
│   │   └── app.ts                  # CDK entry point
│   ├── stacks/
│   │   ├── DatabaseStack.ts        # DynamoDB tables + S3
│   │   ├── ApiStack.ts             # API Gateway + subscriber lambdas
│   │   ├── NewsletterStack.ts      # Step Functions + workflow lambdas
│   │   ├── SchedulerStack.ts       # EventBridge rule
│   │   ├── SecretsStack.ts         # Secrets Manager + IAM
│   │   └── MonitoringStack.ts      # CloudWatch dashboard + alarms
│   ├── config.ts                   # Deployment config
│   └── cdk.json
├── lambdas/
│   ├── shared/                     # Lambda Layer (shared code)
│   │   ├── models/
│   │   │   ├── article.ts
│   │   │   ├── subscriber.ts
│   │   │   └── newsletter.ts
│   │   ├── clients/
│   │   │   └── dynamodb.ts
│   │   ├── utils/
│   │   │   ├── ses-batcher.ts
│   │   │   └── template-cache.ts
│   │   └── validation/
│   │       └── subscriber.ts       # Zod schemas
│   ├── subscribe-handler/
│   │   ├── index.ts
│   │   └── index.test.ts
│   ├── list-subscribers/
│   │   ├── index.ts
│   │   └── index.test.ts
│   ├── unsubscribe-handler/
│   │   ├── index.ts
│   │   ├── unsubscribed.html       # Landing page shown after unsubscribe
│   │   └── index.test.ts
│   ├── fetch-articles/
│   │   ├── index.ts
│   │   └── index.test.ts
│   ├── generate-newsletter/
│   │   ├── index.ts
│   │   ├── template.hbs
│   │   └── index.test.ts
│   ├── send-emails/
│   │   ├── index.ts
│   │   └── index.test.ts
│   ├── mark-newsletter-status/
│   │   ├── index.ts
│   │   └── index.test.ts
│   └── notify-failure/
│       ├── index.ts
│       └── index.test.ts
├── scripts/
│   └── seed-subscribers.ts         # Optional: seed test data
├── package.json
├── tsconfig.json
├── jest.config.ts
└── .env.example
```

---

## AWS Services Breakdown

| Service | Purpose | Replacement For |
|---------|---------|-----------------|
| **API Gateway** (REST) | Subscriber CRUD + unsubscribe endpoint | `SubscriberController` |
| **Lambda** (Node.js 20) | All compute | Spring Boot app |
| **Step Functions** | Newsletter orchestration, retries, error handling | Spring Batch + Quartz |
| **EventBridge Scheduler** | Daily cron trigger (08:00 UTC) | Quartz Scheduler |
| **DynamoDB** | Subscribers + newsletters storage | PostgreSQL + JPA/Hibernate |
| **S3** | Handlebars template + rendered HTML | Thymeleaf (local files) |
| **SES** | Email sending | SES (unchanged concept) |
| **Secrets Manager** | NewsAPI key + AWS credentials | `.env` file + `DotenvConfig` |
| **CloudWatch** | Logging, dashboards, alarms | Spring Boot logs + Actuator |
| **SNS** | Failure notifications | — (new) |

---

## Lambda Specifications

### subscribe-handler

| Property | Value |
|----------|-------|
| Trigger | API Gateway `POST /api/v1/subscribers` |
| Runtime | Node.js 20 (esbuild bundle) |
| Memory | 128 MB |
| Timeout | 10s |
| Environment | `SUBSCRIBERS_TABLE` |

**Behavior:**
1. Validate body with Zod (`{ email: z.string().email() }`)
2. Normalize email to lowercase
3. `DynamoDB PutItem` with `ConditionExpression: attribute_not_exists(email)`
4. On `ConditionalCheckFailedException` → return `409 { error: "DUPLICATE_EMAIL", message: "Email is already registered." }`
5. On success → return `201 { id, email, createdAt, status: "ACTIVE" }`

---

### list-subscribers

| Property | Value |
|----------|-------|
| Trigger | API Gateway `GET /api/v1/subscribers` |
| Runtime | Node.js 20 |
| Memory | 128 MB |
| Timeout | 10s |
| Environment | `SUBSCRIBERS_TABLE` |

**Behavior:**
1. `DynamoDB Scan` on subscribers table
2. Filter items with `status = "ACTIVE"` (or return all with status field)
3. Return `200 { subscribers: [...] }`

---

### unsubscribe-handler

| Property | Value |
|----------|-------|
| Trigger | API Gateway `GET /unsubscribe?email=user@example.com` |
| Runtime | Node.js 20 |
| Memory | 128 MB |
| Timeout | 10s |
| Environment | `SUBSCRIBERS_TABLE` |

**Behavior:**
1. Read `email` from query string, validate format
2. `DynamoDB UpdateItem` — set `status = "UNSUBSCRIBED"`
3. If email not found → return `404` with JSON error
4. On success → return HTML landing page (`Content-Type: text/html`):
   - "You have been unsubscribed from the Digest newsletter."
   - Rendered from a static HTML template bundled in the Lambda

---

### fetch-articles

| Property | Value |
|----------|-------|
| Trigger | Step Functions task |
| Runtime | Node.js 20 |
| Memory | 256 MB |
| Timeout | 30s |
| Environment | `NEWSAPI_KEY_PARAM` (SSM param path), `SEARCH_QUERY`, `LANGUAGE`, `ARTICLE_COUNT` |

**Input:** `{}` (uses env configuration)

**Behavior:**
1. Retrieve NewsAPI key from Secrets Manager (cache in global scope for warm starts)
2. Compute `fromDate = (yesterday).toISOString().split('T')[0]`
3. `axios.get('https://newsapi.org/v2/everything', { params: { q, language, from, pageSize, sortBy: 'publishedAt' }, headers: { 'X-Api-Key': key } })`
4. Map response to `Article[]` (strip irrelevant fields)
5. Return `{ articles: Article[] }` for Step Functions

---

### generate-newsletter

| Property | Value |
|----------|-------|
| Trigger | Step Functions task |
| Runtime | Node.js 20 |
| Memory | 256 MB |
| Timeout | 30s |
| Environment | `TEMPLATE_BUCKET`, `TEMPLATE_KEY`, `NEWSLETTERS_TABLE`, `HTML_BUCKET` |

**Input:** `{ articles: Article[], generatedAt: string }`

**Behavior:**
1. **Cold start:** Download `template.hbs` from S3 → compile with Handlebars → cache in `globalThis`
2. Apply `ulid()` to generate newsletter ID
3. Render HTML: `template({ articles, generatedAt, articleCount })`
4. Store rendered HTML in S3 at `newsletters/{id}.html`
5. `DynamoDB PutItem` — create newsletter record with `status: "GENERATED"`
6. Return `{ id, htmlS3Key }`

---

### send-emails

| Property | Value |
|----------|-------|
| Trigger | Step Functions task |
| Runtime | Node.js 20 |
| Memory | 512 MB |
| Timeout | 120s |
| Environment | `SUBSCRIBERS_TABLE`, `FROM_EMAIL`, `MAX_RETRIES` |

**Input:** `{ newsletterId: string, htmlS3Key: string }`

**Behavior:**
1. `DynamoDB Scan` subscribers with `FilterExpression: #status = :active`
2. If no subscribers → `UpdateItem` newsletter to `SENT`, return early
3. Download full HTML from S3
4. Split emails into batches of 50
5. For each batch: `SES.sendEmail` (with `Source`, `Destination`, `Subject`, `Html`)
6. Retry per batch: exponential backoff `1s * 2^attempt`, max 3 attempts
7. Track `sentCount`, `failedCount`
8. `DynamoDB UpdateItem` newsletter — set `status = "SENT"`, `sentAt = now`
9. Return `{ sentCount, failedCount }`

---

### mark-newsletter-status

| Property | Value |
|----------|-------|
| Trigger | Step Functions task (from `MarkSent` / `MarkFailed`) |
| Runtime | Node.js 20 |
| Memory | 128 MB |
| Timeout | 10s |
| Environment | `NEWSLETTERS_TABLE` |

**Input:** `{ newsletterId: string, status: string, sendResult?: object, error?: object }`

**Behavior:**
1. `DynamoDB UpdateItem` — update `status`, `sentAt` (if SENT), `errorMessage` (if FAILED)
2. Return `{ success: true }`

---

### notify-failure

| Property | Value |
|----------|-------|
| Trigger | Step Functions task (from `NotifyFailure`) |
| Runtime | Node.js 20 |
| Memory | 128 MB |
| Timeout | 15s |
| Environment | `SNS_TOPIC_ARN` |

**Behavior:**
1. Publish to SNS topic with newsletter ID, error details, execution ARN
2. SNS sends email to configured admin address

---

## Step Functions Workflow Definition

```json
{
  "Comment": "Digest Newsletter — Daily Workflow",
  "StartAt": "FetchArticles",
  "States": {
    "FetchArticles": {
      "Type": "Task",
      "Resource": "${FetchArticlesLambdaArn}",
      "ResultPath": "$.articles",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.TooManyRequestsException"],
          "IntervalSeconds": 30,
          "MaxAttempts": 2,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "MarkFailed"
        }
      ],
      "Next": "GenerateNewsletter"
    },
    "GenerateNewsletter": {
      "Type": "Task",
      "Resource": "${GenerateNewsletterLambdaArn}",
      "Parameters": {
        "articles.$": "$.articles",
        "generatedAt.$": "$$.State.EnteredTime"
      },
      "ResultPath": "$.newsletter",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "MarkFailed"
        }
      ],
      "Next": "SendEmails"
    },
    "SendEmails": {
      "Type": "Task",
      "Resource": "${SendEmailsLambdaArn}",
      "Parameters": {
        "newsletterId.$": "$.newsletter.id",
        "htmlS3Key.$": "$.newsletter.htmlS3Key"
      },
      "ResultPath": "$.sendResult",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.TooManyRequestsException"],
          "IntervalSeconds": 10,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.error",
          "Next": "MarkFailed"
        }
      ],
      "Next": "MarkSent"
    },
    "MarkSent": {
      "Type": "Task",
      "Resource": "${MarkStatusLambdaArn}",
      "Parameters": {
        "newsletterId.$": "$.newsletter.id",
        "status": "SENT",
        "sendResult.$": "$.sendResult"
      },
      "End": true
    },
    "MarkFailed": {
      "Type": "Task",
      "Resource": "${MarkStatusLambdaArn}",
      "Parameters": {
        "newsletterId.$": "$.newsletter.id",
        "status": "FAILED",
        "error.$": "$.error"
      },
      "Next": "NotifyFailure"
    },
    "NotifyFailure": {
      "Type": "Task",
      "Resource": "${NotifyFailureLambdaArn}",
      "End": true
    }
  }
}
```

---

## API Gateway Routes

| Method | Path | Lambda | Request | Response |
|--------|------|--------|---------|----------|
| `POST` | `/api/v1/subscribers` | `subscribe-handler` | `{"email": "..."}` | `201` / `409` / `400` |
| `GET` | `/api/v1/subscribers` | `list-subscribers` | — | `200 { subscribers: [...] }` |
| `GET` | `/unsubscribe` | `unsubscribe-handler` | `?email=...` | `200 (HTML)` / `404 (JSON)` |

**Error format (non-HTML responses):**
```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable description"
}
```

| Code | HTTP Status | Condition |
|------|-------------|-----------|
| `DUPLICATE_EMAIL` | 409 | Email already registered |
| `VALIDATION_ERROR` | 400 | Invalid email format or missing field |
| `NOT_FOUND` | 404 | Email not found (unsubscribe) |
| `INTERNAL_ERROR` | 500 | Unexpected Lambda error |

---

## DynamoDB Access Patterns

### subscribers table

| Operation | Expression | Condition |
|-----------|-----------|-----------|
| Create | `PutItem` | `attribute_not_exists(email)` |
| Get by email | `GetItem({ email })` | — |
| List all | `Scan` | Project all fields |
| Unsubscribe | `UpdateItem({ email }, SET #status = :unsub)` | `email` exists |

### newsletters table

| Operation | Expression | Index |
|-----------|-----------|-------|
| Create | `PutItem({ id, title, articleCount, status: "GENERATED", generatedAt, htmlS3Key })` | — |
| Get by ID | `GetItem({ id })` | — |
| Update status | `UpdateItem({ id }, SET #status = :s)` | — |
| List by status | `Query({ status: "SENT" }, scanIndexForward: false)` | GSI: `byStatus` |

---

## CDK Stack Definitions

### DatabaseStack

```
Resources:
  - SubscribersTable (DynamoDB)
    PK: email (String)
    Billing: PAY_PER_REQUEST
    PITR: true
    RemovalPolicy: RETAIN

  - NewslettersTable (DynamoDB)
    PK: id (String)
    Billing: PAY_PER_REQUEST
    PITR: true
    RemovalPolicy: RETAIN
    GSI: byStatus (PK: status, SK: generatedAt)

  - TemplateBucket (S3)
    Encryption: S3_MANAGED
    Versioned: true
    RemovalPolicy: RETAIN
    Lifecycle: expire noncurrent after 30 days

  - HtmlBucket (S3) — rendered newsletters
    Encryption: S3_MANAGED
    RemovalPolicy: DESTROY (ephemeral content)
    Lifecycle: expire objects after 90 days
```

### ApiStack

```
Resources:
  - SubscribeHandlerFn (NodejsFunction)
  - ListSubscribersFn (NodejsFunction)
  - UnsubscribeHandlerFn (NodejsFunction)
  - Api (RestApi)
    - POST /api/v1/subscribers → SubscribeHandlerFn
    - GET /api/v1/subscribers → ListSubscribersFn
    - GET /unsubscribe → UnsubscribeHandlerFn
  - Lambda permissions for DynamoDB tables
```

### NewsletterStack

```
Resources:
  - FetchArticlesFn (NodejsFunction)
    Env: SEARCH_QUERY, LANGUAGE, ARTICLE_COUNT
    Permissions: SecretsManager GetSecretValue

  - GenerateNewsletterFn (NodejsFunction)
    Env: TEMPLATE_BUCKET, TEMPLATE_KEY
    Permissions: S3 GetObject (template), S3 PutObject (html)
    Permissions: DynamoDB PutItem (newsletters)

  - SendEmailsFn (NodejsFunction)
    Env: FROM_EMAIL
    Permissions: SES SendEmail
    Permissions: DynamoDB Scan (subscribers), UpdateItem (newsletters)
    Permissions: S3 GetObject (html)

  - MarkNewsletterStatusFn (NodejsFunction)
    Permissions: DynamoDB UpdateItem

  - NotifyFailureFn (NodejsFunction)
    Env: SNS_TOPIC_ARN
    Permissions: SNS Publish

  - NewsletterStateMachine (Step Functions)
    Definition: JSON as specified above
    Timeout: 15 minutes
    Logging: ALL (CloudWatch)
    Tracing: Active (X-Ray)

  - NewsletterSnsTopic (SNS)
    Email subscription (admin)
```

### SchedulerStack

```
Resources:
  - NewsletterSchedule (Events Rule)
    Schedule: cron(0 8 * * ? *)
    Target: NewsletterStateMachine
    Input: {} (empty input)
```

### SecretsStack

```
Resources:
  - NewsApiKeySecret (Secrets Manager)
    Secret: NEWSAPI_KEY from deploy-time parameter

  - SesFromEmailParameter (SSM String)
    Value: noreply@digest.local
```

### MonitoringStack

```
Resources:
  - DigestDashboard (CloudWatch Dashboard)
    Widgets:
      - Step Functions: execution count, duration, failures (last 14d)
      - Lambda: invocations, errors, p50/p99 duration
      - DynamoDB: consumed capacity, throttled requests
      - SES: send count, bounces, complaints
      - API Gateway: 4xx/5xx, latency

  - WorkflowFailureAlarm (CloudWatch Alarm)
    Metric: Step Functions executions failed
    Threshold: > 0 for 1 consecutive period
    Action: SNS topic

  - SesBounceRateAlarm (CloudWatch Alarm)
    Metric: SES BounceRate
    Threshold: > 5%
    Action: SNS topic

  - LambdaErrorAlarm (CloudWatch Alarm)
    Metric: Sum of errors across all workflow Lambdas
    Threshold: > 0 for 1 consecutive period
    Action: SNS topic
```

---

## Key Dependencies (package.json)

```json
{
  "name": "digest",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "cdk": "cdk",
    "cdk:deploy": "cdk deploy --all",
    "cdk:diff": "cdk diff",
    "cdk:synth": "cdk synth",
    "test": "jest",
    "test:watch": "jest --watch",
    "lint": "tsc --noEmit",
    "seed": "ts-node scripts/seed-subscribers.ts"
  },
  "dependencies": {
    "@aws-sdk/client-dynamodb": "^3.600.0",
    "@aws-sdk/lib-dynamodb": "^3.600.0",
    "@aws-sdk/client-ses": "^3.600.0",
    "@aws-sdk/client-s3": "^3.600.0",
    "@aws-sdk/client-secrets-manager": "^3.600.0",
    "@aws-sdk/client-sns": "^3.600.0",
    "handlebars": "^4.7.8",
    "zod": "^3.23.0",
    "ulid": "^2.3.0",
    "axios": "^1.7.0"
  },
  "devDependencies": {
    "aws-cdk-lib": "^2.150.0",
    "aws-cdk": "^2.150.0",
    "constructs": "^10.0.0",
    "esbuild": "^0.23.0",
    "@types/aws-lambda": "^8.10.0",
    "@types/node": "^20.0.0",
    "typescript": "^5.5.0",
    "jest": "^29.7.0",
    "@types/jest": "^29.5.0",
    "ts-jest": "^29.2.0",
    "ts-node": "^10.9.0",
    "aws-sdk-client-mock": "^4.0.0"
  }
}
```

---

## Deployment

### Prerequisites

```bash
# 1. Install AWS CLI and configure credentials
aws configure

# 2. Bootstrap CDK (first time only in this account/region)
npx cdk bootstrap

# 3. Create .env file
cp .env.example .env
# Edit .env with NEWSAPI_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
```

### Deploy

```bash
# Deploy all stacks
npm run cdk:deploy

# Deploy a specific stack
npx cdk deploy DatabaseStack
```

### CI/CD (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm test
      - run: npx cdk deploy --all --require-approval never
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: us-east-1
          NEWSAPI_KEY: ${{ secrets.NEWSAPI_KEY }}
```

---

## Testing Strategy

| Test Type | Tool | Scope |
|-----------|------|-------|
| Unit tests | Jest | Individual Lambda handlers with mocked AWS SDK |
| Integration | Jest + local Stack | Lambda + DynamoDB + S3 interaction (using `aws-sdk-client-mock`) |
| Infrastructure | CDK assertions (`cdk.assertions.Template`) | Stack generates expected resources |
| E2E | Manual / post-deploy | CloudWatch logs inspection after first scheduled run |

**Example test structure per Lambda:**

```typescript
// lambdas/subscribe-handler/index.test.ts
import { mockClient } from 'aws-sdk-client-mock';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from './index';

const ddbMock = mockClient(DynamoDBDocumentClient);

beforeEach(() => ddbMock.reset());

it('creates a subscriber and returns 201', async () => {
  ddbMock.on(PutCommand).resolves({});
  const result = await handler({ body: JSON.stringify({ email: 'test@example.com' }) });
  expect(result.statusCode).toBe(201);
  const body = JSON.parse(result.body);
  expect(body.email).toBe('test@example.com');
});
```

---

## Phase Migration Plan

```
Phase 1 — Foundation
├── Initialize project (package.json, tsconfig, CDK bootstrap)
├── DatabaseStack (DynamoDB + S3 buckets)
├── Shared Lambda Layer (models, clients, utils)
├── Tests for shared modules
├── CI/CD pipeline
└── Deploy: cdk deploy DatabaseStack

Phase 2 — API Subscriber Management
├── subscribe-handler Lambda + tests
├── list-subscribers Lambda + tests
├── unsubscribe-handler Lambda + tests
├── ApiStack (API Gateway + route integrations)
├── Unsubscribe HTML landing page
└── Deploy: cdk deploy ApiStack

Phase 3 — Newsletter Workflow
├── fetch-articles Lambda + tests
├── generate-newsletter Lambda + tests
├── send-emails Lambda + tests
├── mark-newsletter-status Lambda + tests
├── notify-failure Lambda + tests
├── NewsletterStack (Step Functions + Lambdas)
├── Handlebars template (ported from Thymeleaf)
└── Deploy: cdk deploy NewsletterStack

Phase 4 — Scheduling + Monitoring
├── SchedulerStack (EventBridge rule)
├── MonitoringStack (dashboard + alarms)
├── SecretsStack (Secrets Manager)
├── End-to-end integration verification
└── Deploy: cdk deploy --all

Phase 5 — Go Live
├── Validate first scheduled execution
├── Configure SES domain verification (if not done)
├── Move domain DNS to API Gateway endpoint
└── Decommission old ECS/Spring Boot infrastructure
```

---

## Environment Variables

| Variable | Source | Used By |
|----------|--------|---------|
| `NEWSAPI_KEY` | Secrets Manager | `fetch-articles` |
| `SEARCH_QUERY` | CDK deploy-time | `fetch-articles` (default: `technology`) |
| `LANGUAGE` | CDK deploy-time | `fetch-articles` (default: `en`) |
| `ARTICLE_COUNT` | CDK deploy-time | `fetch-articles` (default: `10`) |
| `FROM_EMAIL` | CDK deploy-time | `send-emails` (default: `noreply@digest.local`) |
| `SUBSCRIBERS_TABLE` | CDK synthesized | `subscribe-handler`, `list-subscribers`, `unsubscribe-handler`, `send-emails` |
| `NEWSLETTERS_TABLE` | CDK synthesized | `generate-newsletter`, `mark-newsletter-status`, `send-emails` |
| `TEMPLATE_BUCKET` | CDK synthesized | `generate-newsletter` |
| `TEMPLATE_KEY` | CDK synthesized | `generate-newsletter` (default: `template.hbs`) |
| `HTML_BUCKET` | CDK synthesized | `generate-newsletter`, `send-emails` |
| `SNS_TOPIC_ARN` | CDK synthesized | `notify-failure` |
| `MAX_RETRIES` | CDK deploy-time | `send-emails` (default: `3`) |
| `AWS_REGION` | Runtime (Lambda) | All AWS SDK calls |

---

## Decommissioned Files (no longer needed)

These files from the current application will not be migrated:

| File | Reason |
|------|--------|
| `pom.xml`, `mvnw`, `mvnw.cmd` | Maven → npm |
| `src/main/java/` | Java → TypeScript |
| `src/main/resources/templates/newsletter-email.html` | Thymeleaf → Handlebars |
| `src/main/resources/application.properties` | Properties → CDK env vars + Secrets Manager |
| `src/main/resources/bootstrap.properties` | Dotenv → Secrets Manager |
| `Dockerfile` | Container → Lambda |
| `docker-compose.yaml` | Local PostgreSQL → DynamoDB |
| `aws/ecs-task-definition.json` | ECS → Lambda |
| `aws/setup-*.sh` | Manual scripts → CDK |
| `.github/workflows/deploy.yml` | Will be rewritten for CDK |
