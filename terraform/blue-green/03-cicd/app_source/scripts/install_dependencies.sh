#!/bin/bash
# Install Apache
yum install -y httpd
systemctl start httpd
systemctl enable httpd
# Copy file ứng dụng vào thư mục web
cp index.html /var/www/html/index.html
