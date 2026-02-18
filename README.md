# MinIO Cluster + Keepalived

Deploys a 3-node MinIO cluster with Keepalived for VIP failover. 


## start

1. **Edit `ansible/deploy.sh`** – set at least:
   - `VM1_IP`, `VM2_IP`, `VM3_IP`, `VIP_ADDRESS`
   - `DEPLOY_USER` – user on the VMs (default `user`); files go to `/home/<DEPLOY_USER>/minio` and `/home/<DEPLOY_USER>/keepalived`
   - `SSH_USER` – SSH login user (e.g. `ubuntu`), must have sudo
   - `MINIO_ROOT_PASSWORD` – **change this**

2. **Run:**
   ```bash
   cd ansible
   ./deploy.sh
   ```


## Configuration (all in `ansible/deploy.sh`)

| Variable | Default | Description |
|----------|---------|-------------|
| **IPs & VIP** | | |
| `VM1_IP` | `192.168.10.4` | VM1 IP |
| `VM2_IP` | `192.168.10.7` | VM2 IP |
| `VM3_IP` | `192.168.10.12` | VM3 IP |
| `VIP_ADDRESS` | `192.168.10.100` | Virtual IP (Keepalived) |
| **Paths** | | |
| `DEPLOY_USER` | `user` | User on VMs; deploy dirs are `/home/<user>/minio` and `/home/<user>/keepalived` |
| `MINIO_DATA_DIR` | `/srv/minio` | MinIO data directory (data1, data2 under this) |
| **Keepalived** | | |
| `PRIORITY_VM1` | `150` | MASTER – holds VIP when healthy |
| `PRIORITY_VM2` | `140` | BACKUP |
| `PRIORITY_VM3` | `130` | BACKUP |
| `KEEPALIVED_INTERFACE` | *(empty)* | e.g. `eth0`; empty = auto-detect |
| `KEEPALIVED_PASS` | `MinIO-Keepalived-Pass-2024` | Keepalived auth password |
| **MinIO** | | |
| `MINIO_ROOT_USER` | `minioadmin` | MinIO console user |
| `MINIO_ROOT_PASSWORD` | *(change!)* | MinIO console password |
| `MINIO_IMAGE` | `docker.arvancloud.ir/minio/minio:latest` | MinIO image |
| `KEEPALIVED_IMAGE` | `arcts/keepalived:latest` | Keepalived image |
| **SSH** | | |
| `SSH_USER` | `ubuntu` | SSH user (non-root with sudo recommended) |
| `SSH_KEY` | *(auto)* | SSH key path; empty = auto-detect from `~/.ssh` |

## pre-requisites

**Where you run `deploy.sh`:**
- Ansible installed
- SSH key-based access to all three VMs

**On each VM (VM1, VM2, VM3):**
- Docker and Docker Compose installed and running
- MinIO and Keepalived images available (playbook checks; load them if needed)
- User `SSH_USER` can sudo (no need to SSH as root)

## What gets deployed

- **Paths on each VM:**
  - `/home/<DEPLOY_USER>/minio/` – `docker-compose.yml`, `.env`
  - `/home/<DEPLOY_USER>/keepalived/` – `keepalived.conf`, `check_minio.sh`
  - `<MINIO_DATA_DIR>/data1`, `<MINIO_DATA_DIR>/data2` – MinIO data (default `/srv/minio/...`)
- **Containers:** MinIO and Keepalived.
- **VIP:** The node with highest priority and healthy MinIO holds the VIP.