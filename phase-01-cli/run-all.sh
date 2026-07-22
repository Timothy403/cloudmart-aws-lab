#!/bin/bash
set -e

cd ~/projects/cloudmart-aws-lab/phase-01-cli

./00-setup.sh
./01-networking.sh
./02-security.sh
./03-storage.sh
./04-database.sh

echo "Waiting for RDS to become available..."
source ../resources.env
aws rds wait db-instance-available --db-instance-identifier $DB_IDENTIFIER

./05-compute.sh
./06-loadbalancer.sh

echo "Waiting for EC2 instances to become healthy..."
sleep 180

./07-monitoring.sh
./08-test.sh

echo "All steps complete"
