# AWS Deployment Quick Start Guide

This guide walks you through deploying Digest to AWS ECS Fargate with automated CI/CD.

## Prerequisites

- AWS Account (with billing enabled)
- AWS CLI installed and configured (`aws configure`)
- Docker installed
- Git with main branch protection (optional but recommended)

## 3-Minute Setup Overview

```
1. Run AWS setup scripts              (5-10 minutes)
   ↓
2. Configure GitHub secrets           (2 minutes)
   ↓
3. Push to main branch                (1 minute)
   → GitHub Actions builds & deploys   (5 minutes)
   ↓
4. Wait for EventBridge trigger       (daily at 08:00 UTC)
   → Task runs and sends newsletters
```

## Step-by-Step Deployment

### Phase 1: Set Up AWS Resources (15 minutes)

**1.1 Create IAM roles and infrastructure**
```bash
cd aws
chmod +x *.sh
./setup-aws.sh
```

This creates:
- IAM roles for ECS tasks
- ECR repository
- ECS cluster
- CloudWatch log group
- CI/CD user (digest-github-actions)

**1.2 Create RDS Database**
```bash
./setup-rds.sh
```

Follow prompts to:
- Enter PostgreSQL password (will be stored in Secrets Manager)
- Wait for database to be created (5-10 minutes)
- Note the RDS endpoint

**1.3 Store Secrets in AWS Secrets Manager**
```bash
./setup-secrets.sh
```

Provide:
- RDS endpoint (from previous step)
- RDS password
- NewsAPI key
- AWS credentials

**1.4 Register ECS Task Definition**
```bash
./setup-ecs.sh
```

This creates:
- ECS task definition
- ECS service (set to 0 desired tasks - only runs on schedule)
- EventBridge rule (daily at 08:00 UTC)

**1.5 Verify SES Email**
```bash
./verify-ses.sh
```

Enter the sender email address that will be used for newsletters. You'll receive a verification email - click the link to verify.

### Phase 2: Configure GitHub for CI/CD (5 minutes)

**2.1 Create CI/CD IAM User Access Keys**
```bash
aws iam create-access-key --user-name digest-github-actions
```

Save the `AccessKeyId` and `SecretAccessKey` from the output.

**2.2 Get Your AWS Account ID**
```bash
aws sts get-caller-identity --query Account --output text
```

**2.3 Add GitHub Repository Secrets**

Go to your GitHub repository:
- Settings → Secrets and variables → Actions
- Click "New repository secret" and add these 6 secrets:

| Secret Name | Value |
|------------|-------|
| `AWS_ACCOUNT_ID` | Your AWS account ID (from step 2.2) |
| `AWS_ACCESS_KEY_ID` | From CI/CD user access keys |
| `AWS_SECRET_ACCESS_KEY` | From CI/CD user access keys |
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY` | `digest` |
| `ECS_CLUSTER_NAME` | `digest-cluster` |
| `ECS_TASK_FAMILY` | `digest-task` |

### Phase 3: Deploy (1 minute)

**3.1 Push to main branch**
```bash
git add .
git commit -m "chore: deploy to AWS"
git push origin main
```

**3.2 Monitor deployment**

Go to your GitHub repository:
- Click "Actions" tab
- Watch the workflow run
- Should complete in ~5 minutes

### Phase 4: Verify Everything (2 minutes)

**4.1 Check ECS Service**
```bash
aws ecs describe-services \
  --cluster digest-cluster \
  --services digest-service \
  --query 'services[0].[serviceName,status,deployments]' \
  --output table
```

**4.2 Check EventBridge Rule**
```bash
aws events describe-rule --name digest-daily-newsletter
```

Should show: `"State": "ENABLED"`

**4.3 View Logs**
```bash
aws logs tail /ecs/digest --follow
```

Wait for the next scheduled run (or manually trigger for testing):
```bash
aws ecs run-task \
  --cluster digest-cluster \
  --task-definition digest-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

## Automated CI/CD Flow

After setup, every time you push to `main`:

1. GitHub Actions automatically triggers
2. Builds Docker image
3. Pushes to ECR
4. Updates ECS task definition
5. Next scheduled run (08:00 UTC daily) uses the new code

No manual deployment needed!

## Cost Breakdown

| Service | Estimated Cost | Notes |
|---------|----------------|-------|
| RDS PostgreSQL | $20-30/month | db.t3.micro, eligible for free tier |
| ECS Fargate | $5-15/month | Runs ~1 min/day |
| ECR | $0.50/month | Repository storage |
| EventBridge | ~$1/month | Low volume |
| SES | Free | Up to 62k emails/month free tier |
| CloudWatch Logs | ~$0.50/month | 7-day retention |
| **Total** | **~$27-47/month** | Scales with subscriber count |

## Troubleshooting

### Task fails to start
```bash
aws ecs describe-tasks --cluster digest-cluster --tasks <task-arn>
aws logs tail /ecs/digest --follow
```

### Database connection fails
- Check RDS security group allows inbound on port 5432
- Verify secrets in Secrets Manager
- Check task definition environment variables

### Emails not sending
- Verify sender email is verified in SES
- Check SES sending limits
- Verify task role has SES permissions

### GitHub Actions fails
- Check workflow logs in GitHub Actions tab
- Verify all GitHub secrets are set correctly
- Check AWS credentials and permissions

## Cleaning Up (Stop Charges)

To delete all AWS resources:

```bash
# Delete ECS service
aws ecs delete-service --cluster digest-cluster --service digest-service

# Delete ECS cluster
aws ecs delete-cluster --cluster digest-cluster

# Delete RDS instance (skip final snapshot)
aws rds delete-db-instance --db-instance-identifier digest-postgres --skip-final-snapshot

# Delete ECR repository
aws ecr delete-repository --repository-name digest --force

# Delete secrets
aws secretsmanager delete-secret --secret-id digest/database --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id digest/app --force-delete-without-recovery

# Delete CloudWatch logs
aws logs delete-log-group --log-group-name /ecs/digest

# Delete EventBridge rule
aws events remove-targets --rule digest-daily-newsletter --ids "1"
aws events delete-rule --name digest-daily-newsletter

# Delete IAM roles (if not used elsewhere)
aws iam delete-role --role-name ecsTaskExecutionRole
aws iam delete-role --role-name ecsTaskRole
aws iam delete-role --role-name EventBridgeECSRole
aws iam delete-user --user-name digest-github-actions
```

## Next Steps

1. Review the GitHub Actions workflow: `.github/workflows/deploy.yml`
2. Customize task definition in: `aws/ecs-task-definition.json`
3. Add monitoring alerts in CloudWatch (optional)
4. Set up SNS notifications for failures (optional)

Questions? Check the main README.md for detailed architecture information.
