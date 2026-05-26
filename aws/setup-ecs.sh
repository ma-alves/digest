#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Digest ECS Task Definition Setup ===${NC}"
echo ""

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

read -p "Enter RDS endpoint: " RDS_ENDPOINT

# Read task definition template
TASK_DEF=$(cat aws/ecs-task-definition.json)

# Replace placeholders
TASK_DEF=${TASK_DEF//ACCOUNT_ID/$AWS_ACCOUNT_ID}
TASK_DEF=${TASK_DEF//RDS_ENDPOINT/$RDS_ENDPOINT}

echo -e "${YELLOW}Registering ECS task definition...${NC}"
TASK_DEF_ARN=$(echo "$TASK_DEF" | aws ecs register-task-definition \
  --cli-input-json file:///dev/stdin \
  --region $AWS_REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo -e "${GREEN}✓ Task definition registered${NC}"
echo -e "${GREEN}  ARN: $TASK_DEF_ARN${NC}"
echo ""

# Create ECS Service
echo -e "${YELLOW}Creating ECS Service...${NC}"

# Get VPC and subnet information
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION)
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text --region $AWS_REGION)
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID,Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION)

aws ecs create-service \
  --cluster digest-cluster \
  --service-name digest-service \
  --task-definition $TASK_DEF_ARN \
  --desired-count 0 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}Service already exists${NC}"

echo -e "${GREEN}✓ ECS Service created (desired count: 0)${NC}"
echo ""

# Create EventBridge rule
echo -e "${YELLOW}Creating EventBridge scheduling rule...${NC}"

aws events put-rule \
  --name digest-daily-newsletter \
  --schedule-expression "cron(0 8 * * ? *)" \
  --state ENABLED \
  --description "Trigger Digest newsletter batch job daily at 08:00 UTC" \
  --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}Rule already exists${NC}"

# Get task definition revision
TASK_DEF_REV=$(echo "$TASK_DEF_ARN" | awk -F: '{print $NF}')

# Create EventBridge target
aws events put-targets \
  --rule digest-daily-newsletter \
  --targets "Id"="1","Arn"="arn:aws:ecs:$AWS_REGION:$AWS_ACCOUNT_ID:cluster/digest-cluster","RoleArn"="arn:aws:iam::$AWS_ACCOUNT_ID:role/EventBridgeECSRole","EcsParameters"="{\"LaunchType\":\"FARGATE\",\"TaskDefinitionArn\":\"$TASK_DEF_ARN\",\"NetworkConfiguration\":{\"awsvpcConfiguration\":{\"Subnets\":[\"$SUBNET_ID\"],\"SecurityGroups\":[\"$SECURITY_GROUP_ID\"],\"AssignPublicIp\":\"ENABLED\"}},\"PlatformVersion\":\"LATEST\"}" \
  --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}Target already exists${NC}"

echo -e "${GREEN}✓ EventBridge rule created${NC}"
echo "  Schedule: Daily at 08:00 UTC"
echo ""

echo -e "${GREEN}=== ECS Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Verify SES email (aws/verify-ses.sh)"
echo "2. Add GitHub secrets to your repository"
echo "3. Push to main branch to trigger deployment"
