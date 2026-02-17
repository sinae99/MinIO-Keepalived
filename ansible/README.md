# MinIO Deployment + Keepalived

deploys a 3-node MinIO distributed cluster with keepalived


### Option 1: Edit IPs in the script (Easiest)

1. Edit `deploy.sh` and set your IPs at the top:
   ```bash
   VM1_IP="192.168.1.10"
   VM2_IP="192.168.1.11"
   VM3_IP="192.168.1.12"
   VIP_ADDRESS="192.168.1.100"
   ```

2. Run the script:
   ```bash
   cd ansible
   ./deploy.sh
   ```

### Option 2: Pass IPs as arguments

```bash
./deploy.sh VM1_IP VM2_IP VM3_IP VIP
```

Example:
```bash
./deploy.sh 192.168.1.10 192.168.1.11 192.168.1.12 192.168.1.100
```

## Architecture

- **3 VMs**: Each running MinIO in distributed mode
- **Keepalived**: Provides VIP failover (VM1 is MASTER with priority 150, VM2 priority 140, VM3 priority 130)
- **Health Checks**: Keepalived monitors MinIO health and fails over VIP if MinIO is down

## Prerequisites

1. **On your local machine (laptop)**:
   - Ansible installed (`sudo apt-get install ansible` or `pip install ansible`)
   - SSH access to all 3 VMs
   - SSH key configured for passwordless access (or you'll be prompted for passwords)

2. **On remote VMs**:
   - Ubuntu/Debian or RHEL/CentOS Linux
   - Internet access to pull Docker images
   - Root or sudo access

## Configuration

Edit `deploy.sh` to customize:

- **Required**: VM1_IP, VM2_IP, VM3_IP, VIP_ADDRESS
- **Optional**: 
  - `KEEPALIVED_PASS`: Keepalived authentication password
  - `MINIO_ROOT_PASSWORD`: MinIO root password (CHANGE THIS!)
  - `SSH_USER`: SSH username (default: root)
  - `SSH_KEY`: SSH key path (default: ~/.ssh/id_rsa)

## What the Playbook Does

1. **Installs dependencies**:
   - Docker and Docker Compose
   - Keepalived
   - Netcat (for health checks)
   - Python Docker SDK

2. **Configures MinIO**:
   - Creates data directories (`/srv/minio/data1`, `/srv/minio/data2`)
   - Deploys docker-compose.yml with distributed mode configuration
   - Deploys .env file with credentials and IPs

3. **Configures Keepalived**:
   - Sets VM1 as MASTER (priority 150)
   - Sets VM2 and VM3 as BACKUP (priorities 140, 130)
   - Configures VIP with health checks
   - Deploys MinIO health check script

4. **Starts services**:
   - Starts Docker service
   - Starts keepalived service
   - Pulls MinIO image and starts containers
   - Waits for MinIO to be ready

## Accessing MinIO

After deployment, access MinIO via the VIP:

- **API Endpoint**: `http://VIP_ADDRESS:9000`
- **Console**: `http://VIP_ADDRESS:9001`
- **Username**: As configured in `deploy.sh` (default: `minioadmin`)
- **Password**: As configured in `deploy.sh`

## Failover Testing

To test VIP failover:

1. Stop MinIO on VM1 (the current MASTER):
   ```bash
   ssh vm1_ip "docker stop minio"
   ```

2. Keepalived should detect MinIO is down and failover VIP to VM2 or VM3

3. Check VIP ownership:
   ```bash
   ip addr show | grep VIP_ADDRESS
   ```

## Troubleshooting

### Check keepalived status:
```bash
ansible minio_nodes -i inventory.yml -e @vars.yml -m shell -a "systemctl status keepalived"
```

### Check MinIO status:
```bash
ansible minio_nodes -i inventory.yml -e @vars.yml -m shell -a "docker ps | grep minio"
```

### View keepalived logs:
```bash
ansible minio_nodes -i inventory.yml -e @vars.yml -m shell -a "journalctl -u keepalived -f"
```

### View MinIO logs:
```bash
ansible minio_nodes -i inventory.yml -e @vars.yml -m shell -a "docker logs minio"
```
