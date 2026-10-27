proxmox_endpoint = "https://10.0.10.2:8006/"
node_name        = "pve01"
enabled          = true
subnet           = "10.0.20.0/24"
octets = {
  jump = 61
  hub  = 62
  edge = 63
}
ssh_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpbAlfspXELv2QcKCV1O2k6jYvc73bUKlfBca3oyCSE twan@laptop",
]
