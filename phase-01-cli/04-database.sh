#!/bin/bash
set -e

if grep -q "^DB_IDENTIFIER=" ../resources.env 2>/dev/null; then
  echo "ERROR: database already provisioned. Run ./09-cleanup.sh first."
  exit 1
fi

source ../resources.env

DB_PASSWORD=$(openssl rand -base64 24)

aws rds create-db-subnet-group --db-subnet-group-name cloudmart-db-subnet-group-$SUFFIX --db-subnet-group-description "Subnets for CloudMart RDS" --subnet-ids "[\"$SUBNET_A\",\"$SUBNET_B\"]"

DB_IDENTIFIER=cloudmart-db-$SUFFIX

aws rds create-db-instance --db-instance-identifier $DB_IDENTIFIER --db-instance-class db.t3.micro --engine mysql --master-username admin --master-user-password $DB_PASSWORD --allocated-storage 10 --vpc-security-group-ids $DB_SG --db-subnet-group-name cloudmart-db-subnet-group-$SUFFIX --no-publicly-accessible --backup-retention-period 1 --tags Key=Name,Value=cloudmart-db

echo "RDS is provisioning. This takes ~5-10 minutes."
echo "Run this to wait: aws rds wait db-instance-available --db-instance-identifier $DB_IDENTIFIER"

RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --query 'DBInstances[0].Endpoint.Address' --output text)

cat >> ../resources.env <<EOF
DB_IDENTIFIER=$DB_IDENTIFIER
RDS_ENDPOINT=$RDS_ENDPOINT
DB_PASSWORD=$DB_PASSWORD
EOF

echo "RDS endpoint: $RDS_ENDPOINT"
echo "Password saved to resources.env"
