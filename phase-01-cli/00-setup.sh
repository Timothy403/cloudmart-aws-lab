#!/bin/bash
set -e

export AWS_REGION=eu-west-2
export MY_IP=$(curl -s https://checkip.amazonaws.com)
export SUFFIX=$(date +%s)

echo "Region: $AWS_REGION"
echo "Your IP: $MY_IP"
echo "Suffix: $SUFFIX"

aws sts get-caller-identity
