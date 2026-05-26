# Digest

## Quick Start - Local Development

To run the application locally with actual AWS:

1. Copy `.env.example` to `.env` and add your actual AWS credentials
2. Start PostgreSQL: `docker-compose up -d postgres`
3. Run the app: `./mvnw spring-boot:run`

The AWS SDK will automatically use the credentials from `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

---

## AWS Deployment Guide - Serverless Architecture

This guide walks you through deploying Digest as a fully serverless application on AWS, optimized for minimal cost and suitable for a few hundred subscribers.

### Architecture Overview

```
EventBridge Rule (Daily @ 08:00 AM UTC)
  ↓
Lambda Function (Triggers batch job)
  ↓
ECS Fargate Container (Spring Boot App)
  ├─→ Fetches articles from NewsAPI
  ├─→ Generates newsletter
  └─→ Sends via AWS SES
  ↓
RDS PostgreSQL (Stores subscribers & newsletters)
  ↓
CloudWatch Logs (Monitoring & Debugging)
  ↓
SNS Notifications (Optional: alerts on failures)
```

### AWS Services Used

| Service | Purpose | Estimated Cost (Monthly) |
|---------|---------|--------------------------|
| **RDS PostgreSQL** | Managed database | ~$20-30 (db.t3.micro) |
| **ECS Fargate** | Container runtime | ~$5-15 (runs once daily) |
| **EventBridge** | Job scheduling | ~$1 (pay per rule + invocations) |
| **ECR** | Container registry | ~$0.50 (storage) |
| **SES** | Email delivery | Free tier (62k/month) |
| **CloudWatch** | Logs & monitoring | ~$0.50 (log storage) |
| **Secrets Manager** | Credentials storage | ~$0.40/secret |
| **Total Estimated** | | **~$27-47/month** |

### Prerequisites

- AWS Account with billing enabled
- AWS CLI installed and configured (`aws configure`)
- Docker installed locally
- Java 25 and Maven installed

### Step-by-Step Deployment

#### Phase 1: AWS Account Setup

**1.1 Create IAM User (Recommended)**
```bash
# Create a user for managing Digest resources
aws iam create-user --user-name digest-deployer

# Attach necessary policies
aws iam attach-user-policy --user-name digest-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
aws iam attach-user-policy --user-name digest-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam attach-user-policy --user-name digest-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
aws iam attach-user-policy --user-name digest-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess
aws iam attach-user-policy --user-name digest-deployer \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
aws iam attach-user-policy --user-name digest-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess
```

**1.2 Set AWS Region**
```bash
# Use us-east-1 (recommended for SES availability and cost)
export AWS_REGION=us-east-1
```

#### Phase 2: Database Setup (RDS PostgreSQL)

**2.1 Create RDS Instance**
```bash
aws rds create-db-instance \
  --db-instance-identifier digest-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 17.1 \
  --master-username postgres \
  --master-user-password 'YourSecurePasswordHere123!' \
  --allocated-storage 20 \
  --storage-type gp3 \
  --publicly-accessible true \
  --backup-retention-period 7 \
  --enable-cloudwatch-logs-exports postgresql

# Wait for instance to be available (5-10 minutes)
aws rds describe-db-instances --db-instance-identifier digest-postgres \
  --query 'DBInstances[0].DBInstanceStatus'
```

**2.2 Get Database Endpoint**
```bash
aws rds describe-db-instances --db-instance-identifier digest-postgres \
  --query 'DBInstances[0].Endpoint.Address' --output text
# Example output: digest-postgres.c9akciq32.us-east-1.rds.amazonaws.com
```

**2.3 Create Database & Schema**
```bash
# Connect to RDS using psql or AWS Management Console
psql -h <your-rds-endpoint> -U postgres -d postgres

# Then run:
CREATE DATABASE digest;
\c digest
-- Schema will be auto-created by Hibernate DDL
```

#### Phase 3: Secrets Management

**3.1 Store Database Credentials in Secrets Manager**
```bash
aws secretsmanager create-secret \
  --name digest/database \
  --description "Digest database credentials" \
  --secret-string '{
    "username": "postgres",
    "password": "YourSecurePasswordHere123!",
    "host": "<your-rds-endpoint>",
    "port": 5432,
    "dbname": "digest"
  }'
```

**3.2 Store Application Secrets**
```bash
aws secretsmanager create-secret \
  --name digest/app \
  --description "Digest application secrets" \
  --secret-string '{
    "NEWSAPI_KEY": "your-newsapi-key",
    "AWS_ACCESS_KEY_ID": "your-aws-key",
    "AWS_SECRET_ACCESS_KEY": "your-aws-secret",
    "AWS_REGION": "us-east-1"
  }'
```

#### Phase 4: Container Preparation

**4.1 Create Dockerfile**
```dockerfile
# Create file: Dockerfile
FROM eclipse-temurin:25-jdk-alpine

WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Copy source code
COPY src src

# Build application
RUN chmod +x mvnw && ./mvnw clean package -DskipTests

# Extract jar
RUN mkdir -p target/dependency && cd target/dependency && \
    jar -xf ../digest-*.jar

# Runtime stage
FROM eclipse-temurin:25-jre-alpine

WORKDIR /app

# Copy from build stage
COPY --from=0 /app/target/dependency/BOOT-INF/lib ./lib
COPY --from=0 /app/target/dependency/BOOT-INF/classes ./classes
COPY --from=0 /app/target/dependency/META-INF ./META-INF

# Expose port for local testing
EXPOSE 8080

# Run application
ENTRYPOINT ["java", "-cp", ".:classes:lib/*", "com.example.digest.DigestApplication"]
```

**4.2 Create ECR Repository**
```bash
aws ecr create-repository --repository-name digest

# Get login token
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

**4.3 Build and Push Docker Image**
```bash
# Build image
docker build -t digest:latest .

# Tag for ECR
docker tag digest:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/digest:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/digest:latest
```

#### Phase 5: ECS Fargate Setup

**5.1 Create ECS Cluster**
```bash
aws ecs create-cluster --cluster-name digest-cluster
```

**5.2 Create Task Execution Role**
```bash
# Create trust policy document
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

**5.3 Create Task Role**
```bash
# Create role for the application to access AWS services
cat > task-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name ecsTaskRole \
  --assume-role-policy-document file://task-trust-policy.json

# Attach SES permissions
aws iam put-role-policy --role-name ecsTaskRole \
  --policy-name SESAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        "Resource": "*"
      }
    ]
  }'
```

**5.4 Create ECS Task Definition**
```bash
# Create file: task-definition.json
cat > task-definition.json << 'EOF'
{
  "family": "digest-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "digest",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/digest:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "spring.datasource.url",
          "value": "jdbc:postgresql://RDS_ENDPOINT:5432/digest"
        },
        {
          "name": "spring.datasource.username",
          "value": "postgres"
        },
        {
          "name": "aws.ses.region",
          "value": "us-east-1"
        }
      ],
      "secrets": [
        {
          "name": "spring.datasource.password",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:digest/database:password::"
        },
        {
          "name": "NEWSAPI_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:digest/app:NEWSAPI_KEY::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/digest",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

# Replace ACCOUNT_ID and RDS_ENDPOINT with actual values
# Then register the task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

**5.5 Create CloudWatch Log Group**
```bash
aws logs create-log-group --log-group-name /ecs/digest
aws logs put-retention-policy --log-group-name /ecs/digest --retention-in-days 7
```

#### Phase 6: EventBridge Scheduling

**6.1 Create IAM Role for EventBridge**
```bash
# Create trust policy
cat > eventbridge-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role --role-name EventBridgeECSRole \
  --assume-role-policy-document file://eventbridge-trust.json

# Attach policy
aws iam put-role-policy --role-name EventBridgeECSRole \
  --policy-name ECSTaskExecute \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "ecs:RunTask",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "iam:PassRole",
        "Resource": "*"
      }
    ]
  }'
```

**6.2 Create EventBridge Rule**
```bash
# Create rule to trigger daily at 08:00 UTC
aws events put-rule \
  --name digest-daily-newsletter \
  --schedule-expression "cron(0 8 * * ? *)" \
  --state ENABLED \
  --description "Trigger Digest newsletter batch job daily at 08:00 UTC"
```

**6.3 Add ECS Target to EventBridge Rule**
```bash
aws events put-targets \
  --rule digest-daily-newsletter \
  --targets "Id"="1","Arn"="arn:aws:ecs:us-east-1:ACCOUNT_ID:cluster/digest-cluster","RoleArn"="arn:aws:iam::ACCOUNT_ID:role/EventBridgeECSRole","EcsParameters"="{\"LaunchType\":\"FARGATE\",\"TaskDefinitionArn\":\"arn:aws:ecs:us-east-1:ACCOUNT_ID:task-definition/digest-task:1\",\"NetworkConfiguration\":{\"awsvpcConfiguration\":{\"Subnets\":[\"subnet-xxxxx\"],\"SecurityGroups\":[\"sg-xxxxx\"],\"AssignPublicIp\":\"ENABLED\"}},\"PlatformVersion\":\"LATEST\"}"
```

#### Phase 7: SES Setup

**7.1 Verify Sender Email**
```bash
aws ses verify-email-identity --email-address noreply@yourdomain.com

# Check verification status
aws ses list-verified-email-addresses
```

**7.2 Request Production Access (Optional)**
If you need to send to addresses other than verified ones:
```bash
aws ses put-account-sending-attributes --tls-policy Required
```

#### Phase 8: Verification & Monitoring

**8.1 Test Task Definition Manually**
```bash
aws ecs run-task \
  --cluster digest-cluster \
  --task-definition digest-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxxxx],securityGroups=[sg-xxxxx],assignPublicIp=ENABLED}"
```

**8.2 View Logs**
```bash
# Stream logs in real-time
aws logs tail /ecs/digest --follow
```

**8.3 Check EventBridge Rule**
```bash
# List all rules
aws events list-rules

# Describe digest rule
aws events describe-rule --name digest-daily-newsletter
```

#### Phase 9: Cost Optimization Tips

1. **RDS**: Use `db.t3.micro` (eligible for free tier for 12 months if new account)
2. **Fargate**: Task runs once daily (~1 minute), minimal CPU/memory needed
3. **SES**: Free tier includes 62,000 recipient emails per month
4. **CloudWatch Logs**: Set retention to 7 days (delete older logs)
5. **Data Transfer**: All services in same region (us-east-1) = no inter-region costs

#### Phase 10: Troubleshooting

**Issue: Task fails to start**
```bash
# Check task logs
aws ecs describe-tasks --cluster digest-cluster --tasks <task-arn>

# View detailed logs
aws logs tail /ecs/digest --follow
```

**Issue: Database connection fails**
- Verify RDS security group allows inbound on port 5432
- Check environment variables in task definition
- Verify secrets in Secrets Manager

**Issue: Emails not sending**
- Verify sender email is verified in SES
- Check SES sending limits (default: 1 email/second)
- Verify task role has SES permissions

**Issue: Newsletter job not triggering**
```bash
# Check EventBridge rule
aws events list-rules

# View rule targets
aws events list-targets-by-rule --rule digest-daily-newsletter
```

### Cleaning Up (Cost Optimization)

To stop incurring charges:

```bash
# Delete ECS resources
aws ecs delete-service --cluster digest-cluster --service digest-service
aws ecs delete-cluster --cluster digest-cluster

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier digest-postgres --skip-final-snapshot

# Delete ECR repository
aws ecr delete-repository --repository-name digest --force

# Delete Secrets Manager secrets
aws secretsmanager delete-secret --secret-id digest/database --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id digest/app --force-delete-without-recovery

# Delete CloudWatch log group
aws logs delete-log-group --log-group-name /ecs/digest

# Delete EventBridge rule
aws events remove-targets --rule digest-daily-newsletter --ids "1"
aws events delete-rule --name digest-daily-newsletter
```

---

## CI/CD Pipeline - GitHub Actions

This project includes automated CI/CD using GitHub Actions to build, test, and deploy to AWS ECS Fargate on every push to `main` branch.

### How It Works

1. **Build Stage**: On every push to `main`, GitHub Actions:
   - Checks out code
   - Builds Docker image
   - Pushes image to AWS ECR

2. **Deploy Stage**: After successful build:
   - Updates ECS task definition with new image
   - Deploys to ECS Fargate cluster
   - Task runs on the next EventBridge trigger (daily at 08:00 UTC)

### Setup GitHub Actions Secrets

Add these secrets to your GitHub repository (`Settings → Secrets and variables → Actions`):

```
AWS_ACCOUNT_ID          → Your AWS account number
AWS_ACCESS_KEY_ID       → AWS credentials for CI/CD user
AWS_SECRET_ACCESS_KEY   → AWS credentials for CI/CD user
AWS_REGION              → us-east-1
ECR_REPOSITORY          → digest
ECS_CLUSTER_NAME        → digest-cluster
ECS_TASK_FAMILY         → digest-task
```

### GitHub Actions Workflow

The workflow file (`.github/workflows/deploy.yml`) automates:

```yaml
name: Build and Deploy to ECS

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Login to Amazon ECR
        run: |
          aws ecr get-login-password --region ${{ secrets.AWS_REGION }} | \
            docker login --username AWS --password-stdin \
            ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com
      
      - name: Build and push Docker image
        run: |
          docker build -t ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com/${{ secrets.ECR_REPOSITORY }}:${{ github.sha }} .
          docker push ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com/${{ secrets.ECR_REPOSITORY }}:${{ github.sha }}
      
      - name: Update ECS task definition
        run: |
          aws ecs update-service \
            --cluster ${{ secrets.ECS_CLUSTER_NAME }} \
            --service digest-service \
            --force-new-deployment
```

### Creating CI/CD IAM User

Create a dedicated AWS IAM user for CI/CD operations:

```bash
# Create CI/CD user
aws iam create-user --user-name digest-github-actions

# Create access key
aws iam create-access-key --user-name digest-github-actions

# Attach necessary permissions
aws iam attach-user-policy --user-name digest-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPushOnly
aws iam attach-user-policy --user-name digest-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonECSFullAccess

# Save the AccessKeyId and SecretAccessKey - you'll need these for GitHub secrets
```

### Manual Deployment (Without CI/CD)

If you want to deploy manually without GitHub Actions:

```bash
# Build and push to ECR
docker build -t digest:latest .
docker tag digest:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/digest:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/digest:latest

# Force new deployment
aws ecs update-service \
  --cluster digest-cluster \
  --service digest-service \
  --force-new-deployment
```

### Monitoring Deployments

```bash
# Check deployment status
aws ecs describe-services --cluster digest-cluster --services digest-service

# View recent task runs
aws ecs list-tasks --cluster digest-cluster --service-name digest-service

# Check logs
aws logs tail /ecs/digest --follow
```

---

## Global Exception Handler

This project implements a centralized exception handling mechanism using Spring's `@ControllerAdvice` annotation. All exceptions thrown throughout the application are caught and standardized into a consistent error response format.

### Architecture

The exception handler is located in `com.example.digest.exception.handler` package and consists of three components:

#### 1. **ErrorCode** (`ErrorCode.java`)
An enum that defines standardized error codes for different exception scenarios:
- `DUPLICATE_EMAIL (1001)` - Email already registered
- `USER_NOT_FOUND (1002)` - User not found
- `VALIDATION_ERROR (1003)` - Request validation failed
- `INTERNAL_SERVER_ERROR (1004)` - Unexpected server error

#### 2. **ErrorResponse** (`ErrorResponse.java`)
A DTO that represents the standardized error response structure:
- `timestamp` - ISO-8601 timestamp when the error occurred
- `status` - HTTP status code
- `error` - HTTP error reason phrase (e.g., "CONFLICT", "BAD_REQUEST")
- `message` - User-friendly error message
- `path` - Request URI path
- `method` - HTTP method (GET, POST, etc.)
- `fieldErrors` - List of validation field errors (only for validation failures)
- `details` - Additional error details (only shown in dev profile for debugging)

#### 3. **GlobalExceptionHandler** (`GlobalExceptionHandler.java`)
The `@ControllerAdvice` class that intercepts and handles all exceptions:

| Exception | HTTP Status | Log Level | Description |
|-----------|-------------|-----------|-------------|
| `DuplicateEmailException` | 409 Conflict | WARN | Email already registered |
| `UserNotFoundException` | 404 Not Found | INFO | User not found |
| `MethodArgumentNotValidException` | 400 Bad Request | DEBUG | Request validation failed (includes all field errors) |
| `HttpMessageNotReadableException` | 400 Bad Request | WARN | Invalid request body format |
| `Exception` (catch-all) | 500 Internal Server Error | ERROR | Unexpected errors |

### Error Response Examples

#### Duplicate Email (409 Conflict)
```json
{
  "timestamp": "2026-04-27T10:40:32",
  "status": 409,
  "error": "CONFLICT",
  "message": "Email is already registered.",
  "path": "/api/v1",
  "method": "POST"
}
```

#### Validation Error (400 Bad Request)
```json
{
  "timestamp": "2026-04-27T10:40:32",
  "status": 400,
  "error": "BAD_REQUEST",
  "message": "Validation failed.",
  "path": "/api/v1",
  "method": "POST",
  "fieldErrors": [
    {
      "field": "email",
      "message": "Formato do e-mail inválido",
      "rejectedValue": "invalid-email"
    }
  ]
}
```

#### User Not Found (404 Not Found)
```json
{
  "timestamp": "2026-04-27T10:40:32",
  "status": 404,
  "error": "NOT_FOUND",
  "message": "User not found.",
  "path": "/api/v1/user/999",
  "method": "GET"
}
```

### Profile-Based Behavior

- **Development Profile (`dev`, `development`)**: The `details` field includes exception class name and message for debugging purposes
- **Production Profile**: The `details` field is omitted for security reasons

Set the active profile in `application.properties`:
```properties
spring.profiles.active=dev
```

### Features

✅ Centralized exception handling  
✅ Standardized error response format  
✅ All validation errors returned at once  
✅ Request context included (path, method, timestamp)  
✅ Environment-aware sensitive data handling  
✅ Appropriate HTTP status codes and log levels  
✅ No changes required to existing controllers or services
