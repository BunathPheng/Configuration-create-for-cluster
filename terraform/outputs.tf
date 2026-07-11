output "external_ips" {
  description = "Public IPs (what Ansible SSHes to)"
  value = {
    for name, inst in google_compute_instance.node :
    name => inst.network_interface[0].access_config[0].nat_ip
  }
}

output "internal_ips" {
  description = "Private IPs (kubelet/etcd bind addresses)"
  value = {
    for name, inst in google_compute_instance.node :
    name => inst.network_interface[0].network_ip
  }
}

output "next_step" {
  value = "Inventory written to ../kubespray/inventory/mycluster/inventory.ini - run: ansible -i inventory/mycluster/inventory.ini all -m ping"
}
