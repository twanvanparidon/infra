#!/bin/sh
# Leave nothing from the build in the image, so every clone starts fresh.
export DEBIAN_FRONTEND=noninteractive

apt-get -y autoremove --purge
apt-get clean
rm -rf /var/lib/apt/lists/*

# cloud-init makes new host keys and a new machine-id on each clone's first boot.
rm -f /etc/ssh/ssh_host_*
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
cloud-init clean --logs --machine-id --seed

journalctl --rotate > /dev/null
journalctl --vacuum-time=1s > /dev/null
fstrim --all
