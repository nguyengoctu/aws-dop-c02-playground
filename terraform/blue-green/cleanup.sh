#!/bin/bash
# Script cleanup các resources do CodeDeploy tạo ra trước khi terraform destroy

set -e

PROJECT_NAME=${1:-"blue-green-lab"}
REGION=${2:-"us-east-1"}

echo "🔍 Tìm và xóa các Auto Scaling Groups do CodeDeploy tạo..."

# Tìm tất cả ASG có prefix CodeDeploy_
ASG_LIST=$(aws autoscaling describe-auto-scaling-groups \
  --region $REGION \
  --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, 'CodeDeploy_${PROJECT_NAME}')].AutoScalingGroupName" \
  --output text)

if [ -z "$ASG_LIST" ]; then
  echo "✅ Không có ASG nào do CodeDeploy tạo"
else
  for ASG_NAME in $ASG_LIST; do
    echo "🗑️  Đang xóa ASG: $ASG_NAME"

    # Scale down về 0
    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name $ASG_NAME \
      --min-size 0 \
      --max-size 0 \
      --desired-capacity 0 \
      --region $REGION

    echo "⏳ Đợi instances terminate..."
    sleep 30

    # Xóa ASG
    aws autoscaling delete-auto-scaling-group \
      --auto-scaling-group-name $ASG_NAME \
      --force-delete \
      --region $REGION

    echo "✅ Đã xóa $ASG_NAME"
  done
fi

echo "🔍 Tìm và xóa Launch Templates do CodeDeploy tạo..."

# Tìm Launch Templates với tag CodeDeployGroupName
LT_LIST=$(aws ec2 describe-launch-templates \
  --region $REGION \
  --filters "Name=tag:CodeDeployGroupName,Values=${PROJECT_NAME}-bg-group" \
  --query "LaunchTemplates[].LaunchTemplateName" \
  --output text)

if [ -z "$LT_LIST" ]; then
  echo "✅ Không có Launch Template nào do CodeDeploy tạo"
else
  for LT_NAME in $LT_LIST; do
    echo "🗑️  Đang xóa Launch Template: $LT_NAME"
    aws ec2 delete-launch-template \
      --launch-template-name $LT_NAME \
      --region $REGION
    echo "✅ Đã xóa $LT_NAME"
  done
fi

echo ""
echo "✅ Cleanup hoàn tất! Giờ có thể chạy terraform destroy an toàn."
echo ""
echo "Thứ tự destroy:"
echo "  cd 03-cicd && terraform destroy -auto-approve"
echo "  cd ../02-infra && terraform destroy -auto-approve"
echo "  cd ../01-core && terraform destroy -auto-approve"
