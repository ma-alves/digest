#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Digest RDS Setup ===${NC}"
echo ""

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

# Prompt for database password
read -sp "Enter PostgreSQL password (min 8 chars): " DB_PASSWORD
echo ""

# Validate password
if [ ${#DB_PASSWORD} -lt 8 ]; then
  echo -e "${RED}Password must be at least 8 characters${NC}"
  exit 1
fi

echo -e "${YELLOW}Creating RDS PostgreSQL instance...${NC}"
aws rds create-db-instance \
  --db-instance-identifier digest-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 17.1 \
  --master-username postgres \
  --master-user-password "$DB_PASSWORD" \
  --allocated-storage 20 \
  --storage-type gp3 \
  --publicly-accessible true \
  --backup-retention-period 7 \
  --enable-cloudwatch-logs-exports postgresql \
  --region $AWS_REGION 2>/dev/null || echo "Instance already exists or error occurred"

echo -e "${YELLOW}Waiting for RDS instance to be available (this may take 5-10 minutes)...${NC}"
aws rds wait db-instance-available \
  --db-instance-identifier digest-postgres \
  --region $AWS_REGION

echo -e "${YELLOW}Getting RDS endpoint...${NC}"
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier digest-postgres \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --region $AWS_REGION)

echo -e "${GREEN}✓ RDS Instance created${NC}"
echo -e "${GREEN}  Endpoint: $RDS_ENDPOINT${NC}"
echo ""

echo -e "${YELLOW}Creating 'digest' database...${NC}"
PGPASSWORD="$DB_PASSWORD" psql -h "$RDS_ENDPOINT" -U postgres -c "CREATE DATABASE digest;" 2>/dev/null || echo "Database already exists"
echo -e "${GREEN}✓ Database created${NC}"
echo ""

echo -e "${GREEN}=== RDS Setup Complete ===${NC}"
echo "Store this information:"
echo "  Host: $RDS_ENDPOINT"
echo "  Port: 5432"
echo "  Database: digest"
echo "  Username: postgres"
echo "  Password: (the one you entered)"
