#!/bin/bash
set -e

source ../resources.env

ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].DNSName' --output text)

echo ""
echo "=================================================="
echo "CloudMart is available at:"
echo "  http://$ALB_DNS"
echo "=================================================="
echo ""

echo "Target health:"
aws elbv2 describe-target-health --target-group-arn $TG_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]'

echo ""
echo "Auto Scaling instances:"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names cloudmart-asg-$SUFFIX --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]'
