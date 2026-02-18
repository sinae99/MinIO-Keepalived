#!/bin/bash

# MinIO Cluster Cleanup Script
# Removes containers, volumes, and directories created by deploy.sh
# Uses same configuration as deploy.sh

set -e

# ==========================================
# CONFIGURATION - Same as deploy.sh
# ==========================================
VM1_IP="192.168.10.4"
VM2_IP="192.168.10.7"
VM3_IP="192.168.10.12"
VIP_ADDRESS="192.168.10.100"

# Optional: override via arguments: ./cleanup.sh VM1_IP VM2_IP VM3_IP VIP
if [ $# -eq 4 ]; then
    VM1_IP="$1"
    VM2_IP="$2"
    VM3_IP="$3"
    VIP_ADDRESS="$4"
fi

# ==========================================
# PATHS (must match deploy.sh)
# ==========================================
DEPLOY_USER="ubuntu"                                  # Must match deploy.sh
MINIO_DATA_DIR="/srv/minio"                          # Must match deploy.sh

# ==========================================
# SSH
# ==========================================
SSH_USER="ubuntu"
SSH_KEY=""  # Auto-detect from ~/.ssh if empty

# ==========================================
# SCRIPT EXECUTION
# ==========================================
echo "=========================================="
echo "MinIO Cluster Cleanup"
echo "=========================================="
echo ""
echo "This will remove:"
echo "  - Containers: minio, keepalived"
echo "  - Directories: /home/$DEPLOY_USER/minio, /home/$DEPLOY_USER/keepalived"
echo "  - Data directories: $MINIO_DATA_DIR/data1, $MINIO_DATA_DIR/data2"
echo ""
echo "Target VMs:"
echo "  VM1: $VM1_IP"
echo "  VM2: $VM2_IP"
echo "  VM3: $VM3_IP"
echo ""

# Confirmation
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: ansible-playbook is not installed."
    echo "Please install it with: sudo apt-get install ansible (or equivalent)"
    exit 1
fi

# Auto-detect SSH key if not specified
if [ -z "$SSH_KEY" ]; then
    SSH_DIR="$HOME/.ssh"
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
    SSH_KEY="${SSH_KEY/#\~/$HOME}"
fi

# Verify SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found: $SSH_KEY"
    exit 1
fi

# Create vars.yml for cleanup
VARS_FILE="vars.yml"
cat > "$VARS_FILE" <<EOF
# IPs and VIP
vm1_ip: "${VM1_IP}"
vm2_ip: "${VM2_IP}"
vm3_ip: "${VM3_IP}"
vip_address: "${VIP_ADDRESS}"
# Paths
deploy_user: "${DEPLOY_USER}"
minio_data_dir: "${MINIO_DATA_DIR}"
# SSH
ssh_user: "${SSH_USER}"
ssh_key_path: "${SSH_KEY}"
EOF

echo "Starting cleanup..."
echo ""

# Create temporary cleanup playbook
CLEANUP_PLAYBOOK=$(mktemp)
cat > "$CLEANUP_PLAYBOOK" <<'CLEANUP_EOF'
---
- name: Cleanup MinIO Cluster
  hosts: minio_nodes
  become: yes
  vars:
    deploy_home: "/home/{{ deploy_user }}"
    minio_deploy_dir: "{{ deploy_home }}/minio"
    keepalived_config_dir: "{{ deploy_home }}/keepalived"
    
  tasks:
    - name: Stop and remove containers
      shell: |
        cd {{ minio_deploy_dir }} 2>/dev/null && docker compose down -v || true
        docker stop minio keepalived 2>/dev/null || true
        docker rm minio keepalived 2>/dev/null || true
      ignore_errors: yes

    - name: Remove MinIO deployment directory
      file:
        path: "{{ minio_deploy_dir }}"
        state: absent

    - name: Remove keepalived config directory
      file:
        path: "{{ keepalived_config_dir }}"
        state: absent

    - name: Remove MinIO data directories
      file:
        path: "{{ minio_data_dir }}/data{{ item }}"
        state: absent
      loop:
        - 1
        - 2
      ignore_errors: yes

    - name: Remove MinIO data parent directory (if empty)
      file:
        path: "{{ minio_data_dir }}"
        state: absent
      when: minio_data_dir != "/"
      ignore_errors: yes

    - name: Cleanup summary
      debug:
        msg: "Cleanup completed on {{ inventory_hostname }}"
CLEANUP_EOF

# Run cleanup playbook
ansible-playbook \
  -i inventory.yml \
  -e @vars.yml \
  "$CLEANUP_PLAYBOOK"

# Remove temporary playbook
rm -f "$CLEANUP_PLAYBOOK"

echo ""
echo "=========================================="
echo "Cleanup completed!"
echo "=========================================="
echo ""
echo "Removed from all VMs:"
echo "  ✓ Containers: minio, keepalived"
echo "  ✓ Deployment dir: /home/$DEPLOY_USER/minio"
echo "  ✓ Keepalived dir: /home/$DEPLOY_USER/keepalived"
echo "  ✓ Data dirs: $MINIO_DATA_DIR/data1, $MINIO_DATA_DIR/data2"
echo ""
