# Latest Changes — Workflow Infrastructure & Handlers

Built the Step Functions orchestration layer, all 5 workflow Lambda handlers, CloudWatch monitoring, and shared utilities on top of the existing API Gateway foundation.

## What Changed

### New Terraform Modules

| Module | Files | Purpose |
|--------|-------|---------|
| `modules/workflow/` | `main.tf`, `variables.tf`, `outputs.tf`, `templates/workflow.json.tpl` | SNS topic, Step Functions state machine, EventBridge daily scheduler, IAM roles for SFN + scheduler |
| `modules/monitoring/` | `main.tf`, `variables.tf`, `outputs.tf` | CloudWatch dashboard (5 widgets), 3 alarms (workflow failure, SES bounce rate, Lambda errors) |

### Updated `terraform/main.tf`

- Added Secrets Manager for NewsAPI key (`aws_secretsmanager_secret` + version)
- 5 new Lambda modules: `fetch_articles`, `generate_newsletter`, `send_emails`, `mark_newsletter_status`, `notify_failure`
- 8 new IAM policy resources for workflow handler permissions
- Wired `workflow` and `monitoring` modules
- Full dependency graph: database → layer → lambdas → api → workflow → monitoring

### Shared Layer (`handlers/shared/`)

| File | Exports |
|------|---------|
| `models/article.ts` | `Article` interface |
| `models/newsletter.ts` | `Newsletter` interface, `NewsletterStatus` enum (`GENERATED`, `SENT`, `FAILED`) |
| `utils/template-cache.ts` | `compileTemplate()`, `clearCache()` — Handlebars caching (warm start) |
| `utils/ses-batcher.ts` | `sendBatch()` — SES batch of 50, exponential backoff retry |

### Workflow Lambda Handlers

| Handler | Runtime | Timeout | Memory | Behavior |
|---------|---------|---------|--------|----------|
| `fetch-articles` | Node 24 | 30s | 256MB | Secrets Manager → NewsAPI `/v2/everything`, returns `{ articles }` |
| `generate-newsletter` | Node 24 | 30s | 256MB | S3 template → Handlebars render → S3 upload → DynamoDB `GENERATED` |
| `send-emails` | Node 24 | 120s | 512MB | Scan ACTIVE subscribers → SES batch(50) with retry → DynamoDB `SENT` |
| `mark-newsletter-status` | Node 24 | 10s | 128MB | DynamoDB UpdateItem (dynamic: sets sentAt or errorMessage) |
| `notify-failure` | Node 24 | 15s | 128MB | SNS Publish with error details to admin email |

### Step Functions Workflow

```
FetchArticles → GenerateNewsletter → SendEmails → MarkSent
                                        ↓
                                   MarkFailed → NotifyFailure
```

- `FetchArticles`: retry 2x (30s backoff), catch → MarkFailed
- `GenerateNewsletter`: catch → MarkFailed
- `SendEmails`: retry 3x (10s backoff), catch → MarkFailed
- Triggered by EventBridge daily at 08:00 UTC

## Build Artifacts

9 zips in `terraform/lambda-packages/` (1 layer + 8 handlers), built via `npm run build:lambdas`.
