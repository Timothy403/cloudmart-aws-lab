#!/bin/bash
set -e

source ../resources.env

echo "Deleting auto scaling group..."
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name cloudmart-asg-$SUFFIX \
  --force-delete || true

echo "Waiting for EC2 instances to terminate..."
sleep 120

echo "Deleting load balancer..."
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN || true

echo "Waiting for ALB to delete..."
aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN || true
sleep 15

echo "Deleting target group..."
aws elbv2 delete-target-group --target-group-arn $TG_ARN || true

echo "Deleting launch template..."
aws ec2 delete-launch-template --launch-template-name cloudmart-web-template-$SUFFIX || true

echo "Deleting RDS instance..."
aws rds delete-db-instance \
  --db-instance-identifier $DB_IDENTIFIER \
  --skip-final-snapshot \
  --delete-automated-backups || true

echo "Waiting for RDS to delete..."
aws rds wait db-instance-deleted --db-instance-identifier $DB_IDENTIFIER || true

echo "Deleting DB subnet group..."
aws rds delete-db-subnet-group --db-subnet-group-name cloudmart-db-subnet-group-$SUFFIX || true

echo "Deleting S3 bucket including all versions..."
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Suspended || true
aws s3 rm s3://$BUCKET_NAME --recursive || true

aws s3api list-object-versions --bucket $BUCKET_NAME > /tmp/s3-versions.json 2>/dev/null || true

if [ -s /tmp/s3-versions.json ]; then
  python3 - <<PY
import json
with open('/tmp/s3-versions.json') as f:
    data = json.load(f)
versions = data.get('Versions', [])
markers = data.get('DeleteMarkers', [])
objects = [{'Key': o['Key'], 'VersionId': o['VersionId']} for o in versions + markers]
if objects:
    with open('/tmp/s3-delete.json', 'w') as f:
        json.dump({'Objects': objects, 'Quiet': False}, f)
    print(f"Deleting {len(objects)} S3 versions/markers")
else:
    print("No S3 versions or markers to delete")
PY
  if [ -f /tmp/s3-delete.json ]; then
    aws s3api delete-objects --bucket $BUCKET_NAME --delete file:///tmp/s3-delete.json || true
  fi
fi

aws s3api delete-bucket --bucket $BUCKET_NAME || true

echo "Gathering network interfaces in VPC..."
ENIS=$(aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)

echo "Releasing targeted elastic IPs attached to this VPC's network interfaces..."
if [ -n "$ENIS" ]; then
  for eni in $ENIS; do
    EIP_ALLOC=$(aws ec2 describe-addresses \
      --filters "Name=network-interface-id,Values=$eni" \
      --query 'Addresses[*].AllocationId' --output text)
    
    if [ -n "$EIP_ALLOC" ] && [ "$EIP_ALLOC" != "None" ]; then
      for alloc in $EIP_ALLOC; do
        echo "Releasing Elastic IP allocation: $alloc"
        aws ec2 release-address --allocation-id $alloc || true
      done
    fi
  done
fi

echo "Deleting network interfaces in VPC..."
if [ -n "$ENIS" ]; then
  for eni in $ENIS; do
    echo "Deleting network interface $eni"
    aws ec2 delete-network-interface --network-interface-id $eni || true
  done
  echo "Waiting 60 seconds for network interfaces..."
  sleep 60
fi

echo "Deleting security groups in dependency order..."
aws ec2 delete-security-group --group-id $DB_SG || true
aws ec2 delete-security-group --group-id $WEB_SG || true
aws ec2 delete-security-group --group-id $ALB_SG || true

echo "Detaching and deleting internet gateway..."
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID || true
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID || true

echo "Deleting subnets..."
aws ec2 delete-subnet --subnet-id $SUBNET_A || true
aws ec2 delete-subnet --subnet-id $SUBNET_B || true

echo "Deleting route table..."
aws ec2 delete-route-table --route-table-id $RT_ID || true

echo "Deleting VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID || true

echo "Detaching IAM policies..."
aws iam detach-role-policy --role-name cloudmart-ec2-role-$SUFFIX --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess || true
aws iam detach-role-policy --role-name cloudmart-ec2-role-$SUFFIX --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy || true

echo "Deleting IAM instance profile and role..."
aws iam remove-role-from-instance-profile --instance-profile-name $INSTANCE_PROFILE --role-name cloudmart-ec2-role-$SUFFIX || true
aws iam delete-instance-profile --instance-profile-name $INSTANCE_PROFILE || true
aws iam delete-role --role-name cloudmart-ec2-role-$SUFFIX || true

echo "Deleting local resource tracking file..."
rm -f ../resources.env

echo "Cleanup complete"
