#!/bin/sh
# Packages, unattended upgrades and SSH hardening for debian-base.
export DEBIAN_FRONTEND=noninteractive

# First boot still runs apt through cloud-init; wait for it.
cloud-init status --wait > /dev/null || true

apt-get update
apt-get -y full-upgrade
# growpart (cloud-guest-utils) grows the root partition on boot after a resize.
apt-get -y install qemu-guest-agent cloud-init cloud-guest-utils unattended-upgrades

# The default unattended-upgrades config applies security updates only.
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# sshd uses the first value it reads, so this file wins over 50-cloud-init.conf.
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
sshd -t
