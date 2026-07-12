# Lab / free-trial sizing: fits in the $300 GCP credit (~$230-240/month)
# Usage: terraform apply -var project_id=YOUR_PROJECT_ID -var-file=lab.tfvars
#
# 6x e2-medium = 12 vCPUs total. If your free-trial quota blocks this,
# also uncomment the node maps below for a 3-node cluster (6 vCPUs, ~$120/month).

control_plane_machine_type = "e2-medium" # 2 vCPU (shared) / 4 GB
worker_machine_type        = "e2-medium" # 2 vCPU (shared) / 4 GB

disk_size_gb = 50
disk_type    = "pd-balanced"

# Free-trial quota allows only 4 external IPs per region, so run
# 3 control planes (HA etcd) + 1 worker:
worker_nodes = { "k8s-worker-3" = 23 }
