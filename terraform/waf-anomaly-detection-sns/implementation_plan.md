# WAF Anomaly Detection Lab Implementation Plan

## Goal
Implement a Terraform template and test script to demonstrate detecting sudden changes in blocked traffic patterns using AWS WAF, CloudWatch Metric Filters, and CloudWatch Anomaly Detection (Option 3 from the user's query).

## Solution Analysis
The correct solution to the AWS question is:
**"Configure a CloudWatch Logs metric filter to capture blocked requests from the tdojo-waf-logs log group and create a custom metric. Use CloudWatch Anomaly Detection to identify unusual patterns and set up an alarm to notify the DevOps engineer via an SNS topic."**

**Reasoning:**
- **Metric Filter**: Allows isolating "Blocked" requests exactly as required ("ignoring other ... behavior").
- **Anomaly Detection on Metric**: The standard way to detect "sudden changes" without hard thresholds, adapting to baseline.
- **SNS**: Standard notification channel.

## Proposed Changes

### Terraform (`terraform/waf-anomaly-detection-sns/main.tf`)
I will create a comprehensive Terraform template containing:

1.  **Network Basics (Brief)**:
    - VPC, Public Subnets, and Security Group (Allow HTTP 80).
2.  **Target Resource (ALB)**:
    - **Application Load Balancer**: Internet-facing.
    - **Listener**: Port 80, returning a **Fixed Response (200 OK - "Welcome to the Lab")**. This avoids paying for/managing EC2 instances while still providing a valid endpoint to test WAF.
3.  **AWS WAFv2 Web ACL**:
    - **Scope**: REGIONAL (for ALB).
    - **Rule**: A rate-limit rule or a "Block Bad IP" rule to easily trigger blocks.
    - **Association**: Connect Web ACL to the ALB.
    - **Logging**: Configured to send logs to CloudWatch Log Group `tdojo-waf-logs`.
4.  **Monitoring & Alerting**:
    - **CloudWatch Log Group**: `tdojo-waf-logs`.
    - **Metric Filter**: `{ $.action = "BLOCK" }` -> Analytic Metric `BlockedRequests`.
    - **CloudWatch Alarm**:
        - Statistic: `SampleCount` or `Sum`.
        - Anomaly Detection: `ANOMALY_DETECTION_BAND(m1, 2)`.
    - **SNS Topic**: `waf-alerts` with a placeholder email subscription.

### Test Script (`terraform/waf-anomaly-detection-sns/generate_traffic.sh`)
A script to:
1.  Send valid requests (to establish baseline - though AD takes time to train).
2.  Send malicious requests (to trigger blocks).
3.  I will use `curl` in a loop.

## User Review Required
> [!NOTE]
> CloudWatch Anomaly Detection models take up to 24 hours to train and become active. The lab will set up the infrastructure, but the alarm might remain in INSUFFICIENT_DATA state until a model is built.
