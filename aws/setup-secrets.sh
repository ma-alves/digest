#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Digest Secrets Manager Setup ===${NC}"
echo ""

AWS_REGION="us-east-1"

# Collect secrets
echo -e "${YELLOW}Enter your secrets:${NC}"
read -p "RDS endpoint (e.g., digest-postgres.xxx.us-east-1.rds.amazonaws.com): " RDS_ENDPOINT
read -p "RDS password: " RDS_PASSWORD
read -p "NewsAPI key: " NEWSAPI_KEY
read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY

echo ""
echo -e "${YELLOW}Creating secrets in Secrets Manager...${NC}"

# Create database secrets
aws secretsmanager create-secret \
  --name digest/database \
  --description "Digest database credentials" \
  --secret-string "{
    \"username\": \"postgres\",
    \"password\": \"$RDS_PASSWORD\",
    \"host\": \"$RDS_ENDPOINT\",
    \"port\": 5432,
    \"dbname\": \"digest\"
  }" \
  --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}Secret already exists (updating)${NC}"

# Create application secrets
aws secretsmanager create-secret \
  --name digest/app \
  --description "Digest application secrets" \
  --secret-string "{
    \"NEWSAPI_KEY\": \"$NEWSAPI_KEY\",
    \"AWS_ACCESS_KEY_ID\": \"$AWS_ACCESS_KEY_ID\",
    \"AWS_SECRET_ACCESS_KEY\": \"$AWS_SECRET_ACCESS_KEY\",
    \"AWS_REGION\": \"$AWS_REGION\"
  }" \
  --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}Secret already exists (updating)${NC}"

echo -e "${GREEN}✓ Secrets created${NC}"
echo ""
echo -e "${YELLOW}Secrets stored at:${NC}"
echo "  - digest/database"
echo "  - digest/app"
