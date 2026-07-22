#!/bin/bash
set -e

if grep -q "^BUCKET_NAME=" ../resources.env 2>/dev/null; then
  echo "ERROR: storage already provisioned. Run ./09-cleanup.sh first."
  exit 1
fi

source ../resources.env

BUCKET_NAME=cloudmart-static-$SUFFIX

aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "CloudMart Logo" > logo.txt
aws s3 cp logo.txt s3://$BUCKET_NAME/assets/logo.txt

cat >> ../resources.env <<EOF
BUCKET_NAME=$BUCKET_NAME
EOF
