#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment


echo "password123" | passwd root --stdin
sed  -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart

yum install http php git -y
systemctl start httpd
systemctl enable httpd
git clone https://github.com/yousafkhamza/aws-elb-site.git /var/website
cp -r /var/website/*  /var/www/html/
chown -R apache:apache /var/www/html/*
