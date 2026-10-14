# Gateway

`gateway01` (`10.0.10.26`) is the tailnet's subnet router for `10.0.10.0/24` and the SSH bastion into the server range. `pve-prod` creates the VM (`tofu/stacks/pve-prod/vms.tf`); Ansible from the laptop sets it up:

```sh
pbpaste | task gateway:setup   # first run: a one-time tag:gateway auth key on stdin
task gateway:setup             # later runs need no key
```

The playbook installs Tailscale, enables IP forwarding and joins the tailnet as `tag:gateway`; the policy approves its route. If the first run hangs after the join, press Ctrl-C and run it again: the SSH session can drop when the route moves to the tailnet.

CI reaches Proxmox through the gateway, so a broken gateway can only be fixed from the LAN.
