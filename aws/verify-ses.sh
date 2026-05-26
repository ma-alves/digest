#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Digest SES Email Verification ===${NC}"
echo ""

AWS_REGION="us-east-1"

read -p "Enter sender email address to verify: " SENDER_EMAIL

echo -e "${YELLOW}Verifying email identity...${NC}"
aws ses verify-email-identity \
  --email-address "$SENDER_EMAIL" \
  --region $AWS_REGION

echo -e "${GREEN}✓ Verification email sent to $SENDER_EMAIL${NC}"
echo ""
echo -e "${YELLOW}Check your email inbox and click the verification link${NC}"
echo ""
echo "Verified emails:"
aws ses list-verified-email-addresses \
  --region $AWS_REGION \
  --query 'VerifiedEmailAddresses' \
  --output table
