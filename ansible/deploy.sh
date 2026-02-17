#!/bin/bash

# MinIO Cluster Deployment Script with Keepalived VIP
# Just set the IPs below and run: ./deploy.sh

set -e

# ==========================================
# CONFIGURATION - EDIT THESE VALUES
# ==========================================
VM1_IP="192.168.1.10"      # Change this to your VM1 IP
VM2_IP="192.168.1.11"      # Change this to your VM2 IP
VM3_IP="192.168.1.12"      # Change this to your VM3 IP
VIP_ADDRESS="192.168.1.100" # Change this to your VIP

# Optional: Override via command line arguments
# Usage: ./deploy.sh VM1_IP VM2_IP VM3_IP VIP
if [ $# -eq 4 ]; then
    VM1_IP="$1"
    VM2_IP="$2"
    VM3_IP="$3"
    VIP_ADDRESS="$4"
fi

# ==========================================
# DEFAULT VALUES (usually don't need to change)
# ==========================================
KEEPALIVED_INTERFACE=""  # Empty = auto-detect
KEEPALIVED_PASS="MinIO-Keepalived-Pass-2024"  # Change if needed
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="MinIO-Root-Pass-2024-ChangeThis"  # CHANGE THIS!
SSH_USER="root"
SSH_KEY="~/.ssh/id_rsa"
MINIO_IMAGE="docker.arvancloud.ir/minio/minio:latest"

# ==========================================
# SCRIPT EXECUTION
# ==========================================
echo "=========================================="
echo "MinIO Cluster Deployment with Keepalived"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  VM1 IP: $VM1_IP"
echo "  VM2 IP: $VM2_IP"
echo "  VM3 IP: $VM3_IP"
echo "  VIP:    $VIP_ADDRESS"
echo ""

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: ansible-playbook is not installed."
    echo "Please install it with: sudo apt-get install ansible (or equivalent)"
    exit 1
fi

# Expand tilde in SSH key path
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# Create vars.yml
VARS_FILE="vars.yml"
cat > "$VARS_FILE" <<EOF
vm1_ip: "${VM1_IP}"
vm2_ip: "${VM2_IP}"
vm3_ip: "${VM3_IP}"
vip_address: "${VIP_ADDRESS}"
keepalived_interface: "${KEEPALIVED_INTERFACE}"
keepalived_auth_pass: "${KEEPALIVED_PASS}"
minio_root_user: "${MINIO_ROOT_USER}"
minio_root_password: "${MINIO_ROOT_PASSWORD}"
minio_image: "${MINIO_IMAGE}"
ssh_user: "${SSH_USER}"
ssh_key_path: "${SSH_KEY}"
EOF

echo "Configuration saved to $VARS_FILE"
echo ""
echo "Starting deployment..."
echo ""

# Run ansible playbook
ansible-playbook \
  -i inventory.yml \
  -e @vars.yml \
  playbook.yml \
  --ask-become-pass

echo ""
echo "=========================================="
echo "Deployment completed!"
echo "=========================================="
echo ""
echo "MinIO Access:"
echo "  API:     http://${VIP_ADDRESS}:9000"
echo "  Console: http://${VIP_ADDRESS}:9001"
echo "  User:    ${MINIO_ROOT_USER}"
echo "  Pass:    ${MINIO_ROOT_PASSWORD}"
echo ""
