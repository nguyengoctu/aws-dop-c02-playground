#!/bin/bash
# Script này lấy DNS của ALB từ Terraform Output và gửi request liên tục
# Mục đích: Tạo traffic nền để CloudWatch thu thập metric TargetResponseTime

# Tự động chuyển vào thư mục chứa code nếu đang chạy từ root
if [ -d "terraform/blue-green/02-infra" ]; then
    cd terraform/blue-green/02-infra
elif [ -d "02-infra" ]; then
    cd 02-infra
elif [ ! -f "terraform.tfstate" ]; then
    echo "Lỗi: Không tìm thấy thư mục 02-infra hoặc file state!"
    exit 1
fi

echo "Dang lay ALB DNS tu Terraform Output..."
ALB_DNS=$(terraform output -raw alb_dns_name)

if [ -z "$ALB_DNS" ]; then
    echo "Lỗi: Không lấy được ALB DNS. Bạn đã chạy 'terraform apply' ở 02-infra chưa?"
    exit 1
fi

echo "Target: http://$ALB_DNS/"
echo "Dang gui request lien tuc..."
echo "Nhan Ctrl+C de dung."

while true; do
    # Curl lấy status code và total time
    # -s: Silent
    # -o /dev/null: Bỏ qua body
    # -w: Format output
    curl -s -o /dev/null -w "Time: %{time_total}s | Status: %{http_code}\n" http://$ALB_DNS/
    sleep 0.5
done
