# MinIO Cluster with Keepalived VIP

deploys a 3-node MinIO cluster with using keepalived for VIP failover.


- **VM1**: MASTER node (priority 150) - holds VIP initially
- **VM2**: BACKUP node (priority 140)
- **VM3**: BACKUP node (priority 130)
- **VIP**: Automatically fails over to highest priority node with healthy MinIO

## Prerequisites

### On Gateway Machine (where you run deploy.sh)

- **Ansible** installed:
  ```bash
  sudo apt-get install ansible
  # or
  pip install ansible
  ```
- **SSH access** to all 3 VMs (passwordless SSH key recommended)


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

## Start

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

### Step 2: Run

```bash
cd ansible
./deploy.sh
```

The script will:
1. Install required Ansible collections
2. Auto-detect your SSH key
3. Deploy to all 3 VMs
4. Start MinIO and keepalived containers

## Conf


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

## Verification

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

## Failover Testing

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
