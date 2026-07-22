#!/bin/bash
set +e

source ../resources.env

ASG_NAME=cloudmart-asg-$SUFFIX
DB_SUBNET_GROUP=cloudmart-db-subnet-group-$SUFFIX
ROLE_NAME=cloudmart-ec2-role-$SUFFIX
PROFILE_NAME=cloudmart-ec2-profile-$SUFFIX
LT_NAME=cloudmart-web-template-$SUFFIX

echo "Cleaning up..."

aws cloudwatch delete-alarms --alarm-names cloudmart-high-cpu-$SUFFIX
aws cloudwatch delete-dashboards --dashboard-name CloudMart-$SUFFIX

aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASG_NAME --min-size 0 --max-size 0 --desired-capacity 0
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ASG_NAME --force-delete

aws ec2 delete-launch-template --launch-template-name $LT_NAME

LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[0].ListenerArn' --output text)
aws elbv2 delete-listener --listener-arn $LISTENER_ARN
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 delete-target-group --target-group-arn $TG_ARN

echo "Deleting RDS instance..."
aws rds delete-db-instance --db-instance-identifier $DB_IDENTIFIER --skip-final-snapshot --delete-automated-backups
aws rds wait db-instance-deleted --db-instance-identifier $DB_IDENTIFIER

aws rds delete-db-subnet-group --db-subnet-group-name $DB_SUBNET_GROUP

aws s3 rm s3://$BUCKET_NAME --recursive
aws s3api delete-bucket --bucket $BUCKET_NAME

aws iam remove-role-from-instance-profile --instance-profile-name $PROFILE_NAME --role-name $ROLE_NAME
aws iam delete-instance-profile --instance-profile-name $PROFILE_NAME
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam delete-role --role-name $ROLE_NAME

aws ec2 delete-security-group --group-id $DB_SG
aws ec2 delete-security-group --group-id $WEB_SG
aws ec2 delete-security-group --group-id $ALB_SG

aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

aws ec2 delete-subnet --subnet-id $SUBNET_A
aws ec2 delete-subnet --subnet-id $SUBNET_B
aws ec2 delete-vpc --vpc-id $VPC_ID

rm -f ../resources.env trust-policy.json scaling-policy.json user-data.sh launch-template.json logo.txt

echo "Cleanup complete."
