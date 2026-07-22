#!/bin/bash
set -e

if grep -q "^DASHBOARD_NAME=" ../resources.env 2>/dev/null; then
  echo "ERROR: monitoring already provisioned. Run ./09-cleanup.sh first."
  exit 1
fi

source ../resources.env

ASG_NAME=cloudmart-asg-$SUFFIX
DASHBOARD_NAME=CloudMart-$SUFFIX

aws cloudwatch put-metric-alarm --alarm-name cloudmart-high-cpu-$SUFFIX --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 300 --threshold 70 --comparison-operator GreaterThanThreshold --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME --evaluation-periods 2

aws cloudwatch put-dashboard --dashboard-name $DASHBOARD_NAME --dashboard-body '{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [["AWS/EC2","CPUUtilization","AutoScalingGroupName","cloudmart-asg-'$SUFFIX'"]],
        "period": 300,
        "stat": "Average",
        "region": "'$AWS_REGION'",
        "title": "CloudMart ASG CPU"
      }
    }
  ]
}'

cat >> ../resources.env <<EOF
DASHBOARD_NAME=$DASHBOARD_NAME
EOF
