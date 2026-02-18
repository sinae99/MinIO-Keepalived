# Ansible MinIO + Keepalived

All configuration is in **`deploy.sh`**. See the [main README](../README.md) for the full guide.

**Usage:**
```bash
# 1. Edit deploy.sh (IPs, DEPLOY_USER, SSH_USER, MINIO_ROOT_PASSWORD, etc.)
# 2. Run:
./deploy.sh
```

Optional: pass IPs and VIP as arguments:
```bash
./deploy.sh VM1_IP VM2_IP VM3_IP VIP
```

Files on VMs are under `/home/<DEPLOY_USER>/` (default `user`), not `/root`.
