#!/bin/bash
set -e

if [ -f ../resources.env ]; then
  echo "ERROR: resources.env already exists. Run ./09-cleanup.sh first."
  exit 1
fi

source ./00-setup.sh

if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS_REGION is not set. Run ./00-setup.sh first."
  exit 1
fi

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=cloudmart-vpc}]' --query 'Vpc.VpcId' --output text)

SUBNET_A=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${AWS_REGION}a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cloudmart-public-a}]' --query 'Subnet.SubnetId' --output text)

SUBNET_B=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${AWS_REGION}b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cloudmart-public-b}]' --query 'Subnet.SubnetId' --output text)

IGW_ID=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudmart-igw}]' --query 'InternetGateway.InternetGatewayId' --output text)

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cloudmart-public-rt}]' --query 'RouteTable.RouteTableId' --output text)

if [ -z "$VPC_ID" ] || [ -z "$SUBNET_A" ] || [ -z "$SUBNET_B" ] || [ -z "$IGW_ID" ] || [ -z "$RT_ID" ]; then
  echo "ERROR: One or more resource IDs are empty."
  echo "VPC_ID=$VPC_ID"
  echo "SUBNET_A=$SUBNET_A"
  echo "SUBNET_B=$SUBNET_B"
  echo "IGW_ID=$IGW_ID"
  echo "RT_ID=$RT_ID"
  exit 1
fi

aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET_A
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET_B

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_A --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_B --map-public-ip-on-launch

cat > ../resources.env <<EOF
AWS_REGION=$AWS_REGION
MY_IP=$MY_IP
SUFFIX=$SUFFIX
VPC_ID=$VPC_ID
SUBNET_A=$SUBNET_A
SUBNET_B=$SUBNET_B
IGW_ID=$IGW_ID
RT_ID=$RT_ID
EOF

echo "Networking created. Saved to resources.env"
