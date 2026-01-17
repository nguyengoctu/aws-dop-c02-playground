#!/bin/bash
# Install Apache and PHP
yum install -y httpd php
systemctl start httpd
systemctl enable httpd
