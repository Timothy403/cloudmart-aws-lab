#!/bin/bash
set -e

source ../resources.env

ALB_SG=$(aws ec2 create-security-group --group-name cloudmart-alb-sg-$SUFFIX --description "ALB security group" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0

WEB_SG=$(aws ec2 create-security-group --group-name cloudmart-web-sg-$SUFFIX --description "Web server security group" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 80 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 22 --cidr ${MY_IP}/32

DB_SG=$(aws ec2 create-security-group --group-name cloudmart-db-sg-$SUFFIX --description "Database security group" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $DB_SG --protocol tcp --port 3306 --source-group $WEB_SG

cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name cloudmart-ec2-role-$SUFFIX --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name cloudmart-ec2-role-$SUFFIX --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam attach-role-policy --role-name cloudmart-ec2-role-$SUFFIX --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

INSTANCE_PROFILE=$(aws iam create-instance-profile --instance-profile-name cloudmart-ec2-profile-$SUFFIX --query 'InstanceProfile.InstanceProfileName' --output text)
aws iam add-role-to-instance-profile --instance-profile-name cloudmart-ec2-profile-$SUFFIX --role-name cloudmart-ec2-role-$SUFFIX

cat >> ../resources.env <<EOF
ALB_SG=$ALB_SG
WEB_SG=$WEB_SG
DB_SG=$DB_SG
INSTANCE_PROFILE=$INSTANCE_PROFILE
EOF
