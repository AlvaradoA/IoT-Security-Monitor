#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
set -x # Log commands

# 1. System Update & Docker Installation
apt-get update -y
apt-get install -y docker.io docker-compose

# Required for Elasticsearch
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

# 2. Create Directory Structure
STACK_DIR="/opt/iot_stack"
mkdir -p $STACK_DIR/config
mkdir -p $STACK_DIR/logs/suricata
mkdir -p $STACK_DIR/data/{elasticsearch,filebeat}

chown -R ubuntu:ubuntu $STACK_DIR

# Give containers full write access
chmod -R 777 $STACK_DIR/data
chmod -R 777 $STACK_DIR/logs 

# 3. Start Docker
# The provisioner will wait for Docker to be active
systemctl start docker
systemctl enable docker

# This allows the provisioner to execute 'docker-compose' commands.
usermod -aG docker ubuntu

# Give a few seconds for the docker daemon to be fully ready
sleep 5