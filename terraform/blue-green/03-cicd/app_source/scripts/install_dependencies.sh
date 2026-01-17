#!/bin/bash
# Install Apache
yum install -y httpd
systemctl start httpd
systemctl enable httpd
# File index.html đã được copy bởi appspec.yml, không cần cp lại
