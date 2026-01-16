#!/bin/bash

# Check if URL argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <ALB_DNS_NAME>"
  echo "Example: $0 waf-lab-alb-123456789.us-east-1.elb.amazonaws.com"
  exit 1
fi

URL="http://$1"

echo "Targeting: $URL"
echo "Press [CTRL+C] to stop..."

while true; do
  # 1. Send legitimate traffic (approx 80% chance)
  if [ $((RANDOM % 10)) -lt 8 ]; then
    echo "$(date) - Sending NORMAL request..."
    curl -s -o /dev/null -w "%{http_code}\n" "$URL"
  else
    # 2. Send malicious traffic (approx 20% chance)
    # The WAF rule blocks requests with header "x-attack: true"
    echo "$(date) - Sending ATTACK request (should be BLOCKED)..."
    curl -H "x-attack: true" -s -o /dev/null -w "%{http_code}\n" "$URL"
  fi
  
  sleep 1
done
