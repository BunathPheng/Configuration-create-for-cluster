variable "project_id" {
  description = "Your GCP project ID (find it in the GCP console top bar)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-southeast1" # Singapore - closest to UTC+7
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "asia-southeast1-b"
}

variable "ssh_user" {
  description = "SSH login user injected on the VMs"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Public key content for the deploy key (~/.ssh/k8s-deploy.pub)"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFhlEN/ljFkoh0EGz++fDwyzcL5QrnptXUxzWPByTEy5 kubespray-deploy"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH / reach the K8s API from outside. Tighten to <your-ip>/32 for production."
  type        = string
  default     = "0.0.0.0/0"
}

# e2-custom-VCPU-MEM_MB : exact sizing, cheaper than the nearest standard type
variable "control_plane_machine_type" {
  type    = string
  default = "e2-custom-4-8192" # 4 vCPU / 8 GB
}

variable "worker_machine_type" {
  type    = string
  default = "e2-custom-8-16384" # 8 vCPU / 16 GB
}

variable "control_plane_nodes" {
  description = "Control-plane nodes: name => last octet of internal IP"
  type        = map(number)
  default = {
    "k8s-cp-1" = 11
    "k8s-cp-2" = 12
    "k8s-cp-3" = 13
  }
}

variable "worker_nodes" {
  description = "Worker nodes: name => last octet of internal IP"
  type        = map(number)
  default = {
    "k8s-worker-1" = 21
    "k8s-worker-2" = 22
    "k8s-worker-3" = 23
  }
}
