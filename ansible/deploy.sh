#!/bin/bash

# MinIO Cluster Deployment Script with Keepalived VIP
# Just set the IPs below and run: ./deploy.sh

set -e

# ==========================================
# CONFIGURATION - EDIT THESE VALUES
# ==========================================
VM1_IP="192.168.10.4"      # Change this to your VM1 IP
VM2_IP="192.168.10.7"      # Change this to your VM2 IP
VM3_IP="192.168.10.12"     # Change this to your VM3 IP
VIP_ADDRESS="192.168.10.100" # Change this to your VIP

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
SSH_USER="ubuntu"  # Change to "root" if your VMs use root user
SSH_KEY=""  # Will auto-detect if empty
MINIO_IMAGE="docker.arvancloud.ir/minio/minio:latest"
KEEPALIVED_IMAGE="arcts/keepalived:latest"

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

# Install required Ansible collections
echo "Installing required Ansible collections..."
ansible-galaxy collection install -r requirements.yml

# Auto-detect SSH key if not specified
if [ -z "$SSH_KEY" ]; then
    SSH_DIR="$HOME/.ssh"
    # Try common SSH key names in order of preference
    if [ -f "$SSH_DIR/id_ed25519" ]; then
        SSH_KEY="$SSH_DIR/id_ed25519"
    elif [ -f "$SSH_DIR/id_rsa" ]; then
        SSH_KEY="$SSH_DIR/id_rsa"
    elif [ -f "$SSH_DIR/id_ecdsa" ]; then
        SSH_KEY="$SSH_DIR/id_ecdsa"
    else
        echo "Error: No SSH key found. Please set SSH_KEY in the script or create one."
        exit 1
    fi
    echo "Auto-detected SSH key: $SSH_KEY"
else
    # Expand tilde in SSH key path
    SSH_KEY="${SSH_KEY/#\~/$HOME}"
fi

# Verify SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found: $SSH_KEY"
    exit 1
fi

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
keepalived_image: "${KEEPALIVED_IMAGE}"
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
  playbook.yml

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
