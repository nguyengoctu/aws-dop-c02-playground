#!/bin/bash
# This script gets ALB DNS from Terraform Output and sends continuous requests
# Purpose: Generate background traffic for CloudWatch to collect TargetResponseTime metric

# Automatically switch to code directory if running from root
if [ -d "terraform/blue-green/02-infra" ]; then
    cd terraform/blue-green/02-infra
elif [ -d "02-infra" ]; then
    cd 02-infra
elif [ ! -f "terraform.tfstate" ]; then
    echo "Error: 02-infra directory or state file not found!"
    exit 1
fi

echo "Getting ALB DNS from Terraform Output..."
ALB_DNS=$(terraform output -raw alb_dns_name)

if [ -z "$ALB_DNS" ]; then
    echo "Error: Could not get ALB DNS. Have you run 'terraform apply' in 02-infra?"
    exit 1
fi

echo "Target: http://$ALB_DNS/"
echo "Sending continuous requests..."
echo "Press Ctrl+C to stop."

while true; do
    # Curl gets status code and total time
    # -s: Silent
    # -o /dev/null: Ignore body
    # -w: Format output
    curl -s -o /dev/null -w "Time: %{time_total}s | Status: %{http_code}\n" http://$ALB_DNS/
    sleep 0.5
done
