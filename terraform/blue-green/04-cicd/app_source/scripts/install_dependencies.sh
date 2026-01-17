#!/bin/bash
# Install Apache
# Install Apache and PHP
yum install -y httpd php
systemctl start httpd
systemctl enable httpd
# File index.html đã được copy bởi appspec.yml, không cần cp lại
