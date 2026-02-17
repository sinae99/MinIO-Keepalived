# MinIO Distributed Cluster with Keepalived VIP

This project deploys a 3-node MinIO distributed cluster with high availability using keepalived for Virtual IP (VIP) failover.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Verification](#verification)
- [Failover Testing](#failover-testing)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)

## 🎯 Overview

This setup provides:
- **3-node MinIO distributed cluster** for high availability and data redundancy
- **Keepalived VIP failover** - automatic failover if MinIO goes down on any node
- **Offline deployment** - works on VMs without internet access
- **Automated deployment** - single command deployment via Ansible

## 🏗️ Architecture

```
                    ┌─────────────────┐
                    │   VIP: 192.168  │
                    │    .10.100      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
   │  VM1    │         │  VM2    │         │  VM3    │
   │ 192.168 │         │ 192.168 │         │ 192.168 │
   │ .10.4   │         │ .10.7   │         │ .10.12  │
   │         │         │         │         │         │
   │ MinIO   │◄───────►│ MinIO   │◄───────►│ MinIO   │
   │ Keepalived│       │ Keepalived│       │ Keepalived│
   │ (MASTER) │         │ (BACKUP) │         │ (BACKUP) │
   │ Priority │         │ Priority │         │ Priority │
   │   150    │         │   140    │         │   130    │
   └──────────┘         └──────────┘         └──────────┘
```

- **VM1**: MASTER node (priority 150) - holds VIP initially
- **VM2**: BACKUP node (priority 140)
- **VM3**: BACKUP node (priority 130)
- **VIP**: Automatically fails over to highest priority node with healthy MinIO

## 📦 Prerequisites

### On Gateway Machine (where you run deploy.sh)

- **Ansible** installed:
  ```bash
  sudo apt-get install ansible
  # or
  pip install ansible
  ```
- **SSH access** to all 3 VMs (passwordless SSH key recommended)
- **Internet access** (for downloading Ansible collections)

### On Remote VMs (VM1, VM2, VM3)

- **Docker** installed and running
- **Docker Compose** installed
- **MinIO image** loaded: `docker.arvancloud.ir/minio/minio:latest`
- **Keepalived image** loaded: `arcts/keepalived:latest`
- **No internet required** - all packages/configs are transferred from gateway

### Network Requirements

- All VMs must be able to reach each other on ports 9000, 9001
- VRRP protocol (IP protocol 112) must be allowed between nodes
- Firewall rules configured appropriately

## 🚀 Quick Start

### Step 1: Edit Configuration

Edit `ansible/deploy.sh` and set your IP addresses:

```bash
cd ansible
nano deploy.sh
```

Update these lines:
```bash
VM1_IP="192.168.10.4"      # Your VM1 IP
VM2_IP="192.168.10.7"      # Your VM2 IP
VM3_IP="192.168.10.12"     # Your VM3 IP
VIP_ADDRESS="192.168.10.100" # Your VIP
```

**Optional**: Change passwords and other settings:
```bash
MINIO_ROOT_PASSWORD="YourSecurePassword"  # CHANGE THIS!
KEEPALIVED_PASS="YourKeepalivedPassword"  # Change if needed
SSH_USER="ubuntu"  # Change if your VMs use different user
```

### Step 2: Run Deployment

```bash
cd ansible
./deploy.sh
```

The script will:
1. Install required Ansible collections
2. Auto-detect your SSH key
3. Deploy to all 3 VMs
4. Start MinIO and keepalived containers

### Alternative: Pass IPs as Arguments

```bash
./deploy.sh VM1_IP VM2_IP VM3_IP VIP
```

Example:
```bash
./deploy.sh 192.168.10.4 192.168.10.7 192.168.10.12 192.168.10.100
```

## ⚙️ Configuration

### Default Settings

Located in `ansible/deploy.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `VM1_IP` | `192.168.10.4` | IP address of first VM |
| `VM2_IP` | `192.168.10.7` | IP address of second VM |
| `VM3_IP` | `192.168.10.12` | IP address of third VM |
| `VIP_ADDRESS` | `192.168.10.100` | Virtual IP address |
| `MINIO_ROOT_USER` | `minioadmin` | MinIO admin username |
| `MINIO_ROOT_PASSWORD` | `MinIO-Root-Pass-2024-ChangeThis` | MinIO admin password |
| `KEEPALIVED_PASS` | `MinIO-Keepalived-Pass-2024` | Keepalived auth password |
| `SSH_USER` | `ubuntu` | SSH username for VMs |
| `MINIO_IMAGE` | `docker.arvancloud.ir/minio/minio:latest` | MinIO Docker image |
| `KEEPALIVED_IMAGE` | `arcts/keepalived:latest` | Keepalived Docker image |

### Keepalived Priorities

Configured in `ansible/inventory.yml`:
- **VM1**: Priority 150 (MASTER)
- **VM2**: Priority 140 (BACKUP)
- **VM3**: Priority 130 (BACKUP)

The node with highest priority and healthy MinIO will hold the VIP.

## 📥 Deployment Process

The playbook performs these steps on each VM:

1. **Pre-flight checks**
   - Verifies Docker and Docker Compose are installed
   - Checks if required images exist

2. **Network detection**
   - Auto-detects network interface
   - Sets keepalived interface

3. **Configuration deployment**
   - Creates data directories (`/srv/minio/data1`, `/srv/minio/data2`)
   - Deploys keepalived configuration
   - Deploys MinIO configuration
   - Creates docker-compose.yml

4. **Service startup**
   - Stops existing containers
   - Starts MinIO first
   - Waits for MinIO to be ready
   - Starts keepalived

## ✅ Verification

### Check Container Status

On any VM:
```bash
sudo docker ps | grep -E "(minio|keepalived)"
```

Expected output:
```
CONTAINER ID   IMAGE                              STATUS
xxxxx          docker.arvancloud.ir/minio/minio   Up X minutes
xxxxx          arcts/keepalived:latest            Up X minutes
```

### Check VIP Ownership

On any VM:
```bash
ip addr show | grep 192.168.10.100
```

Or check on all VMs:
```bash
for vm in vm1_ip vm2_ip vm3_ip; do
  echo "Checking $vm:"
  ssh $vm "ip addr show | grep 192.168.10.100"
done
```

### Access MinIO Console

Open in browser:
- **URL**: http://192.168.10.100:9001
- **Username**: `minioadmin` (or as configured)
- **Password**: As set in `deploy.sh`

### Check MinIO Cluster Status

```bash
# Via API
curl http://192.168.10.100:9000/minio/health/live

# Check logs
ssh vm1_ip "sudo docker logs minio"
```

## 🔄 Failover Testing

### Test 1: Stop MinIO on MASTER

```bash
# On VM1 (current MASTER)
ssh vm1_ip "sudo docker stop minio"

# Wait 10-15 seconds, then check VIP
ip addr show | grep 192.168.10.100
# VIP should move to VM2 or VM3
```

### Test 2: Stop Entire VM1

```bash
# Shutdown VM1
ssh vm1_ip "sudo shutdown -h now"

# Check VIP on other VMs
ssh vm2_ip "ip addr show | grep 192.168.10.100"
ssh vm3_ip "ip addr show | grep 192.168.10.100"
```

### Test 3: Restart MinIO

```bash
# Restart MinIO on VM1
ssh vm1_ip "sudo docker restart minio"

# After MinIO is healthy, VIP may return to VM1 (if it has highest priority)
```

## 🔧 Troubleshooting

### MinIO Container Restarting

**Symptom**: `docker ps` shows MinIO restarting repeatedly

**Check logs**:
```bash
sudo docker logs minio
```

**Common causes**:
- MinIO can't identify its own IP → Check `.env` file has correct `MY_IP`
- Network connectivity issues → Verify VMs can reach each other
- Port conflicts → Check if ports 9000/9001 are already in use

**Solution**: Re-run deployment:
```bash
cd ansible
./deploy.sh
```

### Keepalived Not Starting

**Symptom**: Keepalived container keeps restarting

**Check logs**:
```bash
sudo docker logs keepalived
```

**Common causes**:
- Interface not detected → Check `keepalived.conf` has correct interface
- Config file errors → Verify `/root/keepalived/keepalived.conf` syntax

**Solution**: Check interface detection:
```bash
# On VM
ip route | grep default | awk '{print $5}'
# Update keepalived.conf if needed
```

### VIP Not Appearing

**Symptom**: No VM has the VIP

**Check**:
```bash
# Check keepalived status on all VMs
for vm in vm1_ip vm2_ip vm3_ip; do
  echo "=== $vm ==="
  ssh $vm "sudo docker logs keepalived | tail -20"
done
```

**Common causes**:
- MinIO health check failing → Check MinIO is running
- Firewall blocking VRRP → Allow IP protocol 112
- Keepalived config errors → Check config file

### Can't Access MinIO via VIP

**Symptom**: Browser/curl can't reach MinIO on VIP

**Check**:
```bash
# Verify VIP exists
ip addr show | grep 192.168.10.100

# Check MinIO is listening
netstat -tlnp | grep 9000

# Test connectivity
curl -v http://192.168.10.100:9000/minio/health/live
```

**Common causes**:
- VIP not assigned → Check keepalived logs
- Firewall blocking → Allow ports 9000, 9001
- MinIO not running → Check container status

### Deployment Fails

**Symptom**: Ansible playbook fails

**Check**:
```bash
# Run with verbose output
ansible-playbook -i inventory.yml -e @vars.yml playbook.yml -vvv
```

**Common issues**:
- SSH connection failed → Verify SSH keys and connectivity
- Docker not installed → Install Docker on VMs first
- Images missing → Load required Docker images
- Permission denied → Ensure SSH user has sudo access

## 📁 Project Structure

```
minio/
├── README.md                    # This file
├── ansible/                     # Ansible deployment files
│   ├── deploy.sh               # Main deployment script
│   ├── playbook.yml            # Ansible playbook
│   ├── inventory.yml           # Host inventory
│   ├── requirements.yml        # Ansible collection requirements
│   ├── vars.yml.example        # Example variables file
│   └── templates/              # Configuration templates
│       ├── docker-compose.yml.j2
│       ├── keepalived.conf.j2
│       ├── minio.env.j2
│       └── check_minio.sh.j2
├── vm1/                         # VM1 configuration (reference)
│   ├── docker-compose.yml
│   ├── .env
│   └── keepalived/
│       ├── keepalived.conf
│       └── check_minio.sh
├── vm2/                         # VM2 configuration (reference)
└── vm3/                         # VM3 configuration (reference)
```

## 🔐 Security Notes

1. **Change Default Passwords**: Update `MINIO_ROOT_PASSWORD` and `KEEPALIVED_PASS` in `deploy.sh`
2. **SSH Keys**: Use SSH key authentication, not passwords
3. **Firewall**: Configure firewall rules to allow:
   - Ports 9000, 9001 (MinIO)
   - IP protocol 112 (VRRP)
   - SSH (port 22)
4. **Network**: Ensure VMs are on a secure network segment

## 📚 Additional Resources

- [MinIO Documentation](https://min.io/docs/)
- [Keepalived Documentation](https://www.keepalived.org/documentation.html)
- [Ansible Documentation](https://docs.ansible.com/)

## 🆘 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review container logs: `sudo docker logs <container_name>`
3. Verify network connectivity between VMs
4. Check Ansible verbose output: `ansible-playbook ... -vvv`

## 📝 Notes

- **Offline Deployment**: This playbook works on VMs without internet by transferring all configurations from the gateway
- **Idempotent**: Safe to run multiple times - it will update configurations as needed
- **Network Mode**: MinIO uses `host` network mode for proper IP binding
- **Data Persistence**: MinIO data is stored in `/srv/minio/data1` and `/srv/minio/data2` on each VM

---

**Last Updated**: February 2026
