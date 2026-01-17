#!/bin/bash
# Hook: BeforeAllowTraffic (Theo yêu cầu đề bài)
# "All temporary files must be deleted before routing traffic to the new fleet"
# "Tất cả file tạm phải bị xóa trước khi điều hướng traffic vào fleet mới"

echo "Dang don dep file tam (Cleaning up)..."
rm -rf /tmp/deployment-artifacts
# Ví dụ: Xóa các file config sinh ra trong quá trình cài đặt
# rm -f /var/www/html/temp_config.json

exit 0
