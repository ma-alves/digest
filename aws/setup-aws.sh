#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Digest AWS Setup Script ===${NC}"
echo "This script will set up all required AWS resources for Digest deployment."
echo ""

# Validate prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is not installed${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq is not installed${NC}"; exit 1; }

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
echo -e "${GREEN}✓ AWS Account ID: $AWS_ACCOUNT_ID${NC}"
echo -e "${GREEN}✓ AWS Region: $AWS_REGION${NC}"
echo ""

# Step 1: Create IAM roles
echo -e "${YELLOW}Step 1: Creating IAM Roles...${NC}"

# Task Execution Role
echo "Creating ecsTaskExecutionRole..."
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
echo -e "${GREEN}✓ ecsTaskExecutionRole created${NC}"

# Task Role
echo "Creating ecsTaskRole..."
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists"

aws iam put-role-policy \
  --role-name ecsTaskRole \
  --policy-name SESAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": "*"
    }]
  }'
echo -e "${GREEN}✓ ecsTaskRole created${NC}"

# EventBridge Role
echo "Creating EventBridgeECSRole..."
aws iam create-role \
  --role-name EventBridgeECSRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "events.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists"

aws iam put-role-policy \
  --role-name EventBridgeECSRole \
  --policy-name ECSTaskExecute \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["ecs:RunTask"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": "*"
    }]
  }'
echo -e "${GREEN}✓ EventBridgeECSRole created${NC}"
echo ""

# Step 2: Create ECR Repository
echo -e "${YELLOW}Step 2: Creating ECR Repository...${NC}"
aws ecr create-repository \
  --repository-name digest \
  --region $AWS_REGION 2>/dev/null || echo "Repository already exists"
echo -e "${GREEN}✓ ECR repository ready${NC}"
echo ""

# Step 3: Create ECS Cluster
echo -e "${YELLOW}Step 3: Creating ECS Cluster...${NC}"
aws ecs create-cluster \
  --cluster-name digest-cluster \
  --region $AWS_REGION 2>/dev/null || echo "Cluster already exists"
echo -e "${GREEN}✓ ECS cluster created${NC}"
echo ""

# Step 4: Create CloudWatch Log Group
echo -e "${YELLOW}Step 4: Creating CloudWatch Log Group...${NC}"
aws logs create-log-group \
  --log-group-name /ecs/digest \
  --region $AWS_REGION 2>/dev/null || echo "Log group already exists"
aws logs put-retention-policy \
  --log-group-name /ecs/digest \
  --retention-in-days 7 \
  --region $AWS_REGION
echo -e "${GREEN}✓ CloudWatch log group created${NC}"
echo ""

# Step 5: Create CI/CD IAM User
echo -e "${YELLOW}Step 5: Setting up CI/CD IAM User...${NC}"
aws iam create-user --user-name digest-github-actions 2>/dev/null || echo "User already exists"
aws iam attach-user-policy \
  --user-name digest-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPushOnly
aws iam attach-user-policy \
  --user-name digest-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonECSFullAccess
echo -e "${YELLOW}✓ CI/CD user created (digest-github-actions)${NC}"
echo -e "${YELLOW}  Generate access keys with:${NC}"
echo -e "${YELLOW}  aws iam create-access-key --user-name digest-github-actions${NC}"
echo ""

echo -e "${GREEN}=== AWS Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Create RDS database (run aws/setup-rds.sh)"
echo "2. Create secrets in Secrets Manager (run aws/setup-secrets.sh)"
echo "3. Add GitHub secrets to your repository"
echo "4. Create ECS task definition (run aws/setup-ecs.sh)"
