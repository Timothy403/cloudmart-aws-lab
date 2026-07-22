#!/bin/bash
set -e

source ../resources.env

TG_ARN=$(aws elbv2 create-target-group --name cloudmart-tg-$SUFFIX --protocol HTTP --port 80 --vpc-id $VPC_ID --target-type instance --health-check-path / --query 'TargetGroups[0].TargetGroupArn' --output text)

ALB_ARN=$(aws elbv2 create-load-balancer --name cloudmart-alb-$SUFFIX --subnets $SUBNET_A $SUBNET_B --security-groups $ALB_SG --scheme internet-facing --type application --tags Key=Name,Value=cloudmart-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)

aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN

aws autoscaling create-auto-scaling-group --auto-scaling-group-name cloudmart-asg-$SUFFIX --launch-template LaunchTemplateName=cloudmart-web-template-$SUFFIX,Version='$Latest' --min-size 1 --max-size 3 --desired-capacity 2 --vpc-zone-identifier "$SUBNET_A,$SUBNET_B" --target-group-arns $TG_ARN --health-check-type ELB --health-check-grace-period 300 --tags "Key=Name,Value=cloudmart-web,PropagateAtLaunch=true"

cat > scaling-policy.json <<EOF
{
  "PredefinedMetricSpecification": { "PredefinedMetricType": "ASGAverageCPUUtilization" },
  "TargetValue": 60.0
}
EOF

aws autoscaling put-scaling-policy --auto-scaling-group-name cloudmart-asg-$SUFFIX --policy-name cloudmart-scale-up-$SUFFIX --policy-type TargetTrackingScaling --target-tracking-configuration file://scaling-policy.json

cat >> ../resources.env <<EOF
TG_ARN=$TG_ARN
ALB_ARN=$ALB_ARN
EOF
