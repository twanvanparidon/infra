#!/usr/bin/env bash
# Boot a debian-base image the way a clone boots and check it. The VM runs on
# a copy-on-write overlay bigger than the image, so the image stays untouched
# and the root filesystem has room to grow. cloud-init gets a throwaway user
# and key, like the vm module sets per VM.
#
# Usage: test.sh <image.qcow2>
# Env:   SSH_PORT     localhost port forwarded to the VM (default 2222)
#        BOOT_TIMEOUT seconds to wait for SSH (default 600)

set -euo pipefail

image=$1
port=${SSH_PORT:-2222}
boot_timeout=${BOOT_TIMEOUT:-600}
disk_size=4G
# The image is 3 GiB; the grown root filesystem must be clearly bigger.
min_root_mb=3500

[[ -f $image ]] || { echo "no image at $image" >&2; exit 1; }

# A short path: unix socket paths must stay under 104 bytes on macOS.
work=$(mktemp -d /tmp/pkrtest.XXXXXX)
cleanup() {
  [[ -f $work/qemu.pid ]] && kill "$(cat "$work/qemu.pid")" 2> /dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

# KVM when this machine has it, else emulation (macOS, or Linux without access).
accel=tcg
[[ -w /dev/kvm ]] && accel=kvm

ssh-keygen -q -t ed25519 -N '' -C packer-test -f "$work/key"
cat > "$work/user-data" << EOF
#cloud-config
users:
  - name: tester
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys: ["$(cat "$work/key.pub")"]
EOF
echo "instance-id: packer-test" > "$work/meta-data"
xorriso -as mkisofs -quiet -o "$work/seed.iso" -V cidata -J -r "$work/user-data" "$work/meta-data" 2> /dev/null
qemu-img create -q -f qcow2 -b "$(cd "$(dirname "$image")" && pwd)/$(basename "$image")" -F qcow2 "$work/disk.qcow2" "$disk_size"

echo "booting $(basename "$image") with $accel"
qemu-system-x86_64 -accel "$accel" -m 2048 -smp 2 \
  -drive "file=$work/disk.qcow2,if=virtio" -drive "file=$work/seed.iso,media=cdrom" \
  -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$port-:22" -device virtio-net-pci,netdev=n0 \
  -chardev "socket,path=$work/qga.sock,server=on,wait=off,id=qga0" \
  -device virtio-serial -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -serial "file:$work/console.log" -display none -pidfile "$work/qemu.pid" -daemonize

# Only the test key: never the caller's agent or default keys.
ssh_opts=(-n -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR -o ConnectTimeout=5 -o BatchMode=yes -o IdentityAgent=none -o IdentitiesOnly=yes)
vm() { ssh "${ssh_opts[@]}" -i "$work/key" tester@127.0.0.1 "$@"; }

deadline=$((SECONDS + boot_timeout))
until vm true 2> /dev/null; do
  if ((SECONDS > deadline)); then
    echo "FAIL  no SSH login within ${boot_timeout}s; last console lines:" >&2
    tail -n 20 "$work/console.log" >&2
    exit 1
  fi
  sleep 5
done
echo "ok    SSH login with the cloud-init key"

failed=0
check() {
  local name=$1
  shift
  local out
  if out=$("$@" 2>&1); then
    echo "ok    $name"
  else
    echo "FAIL  $name${out:+: $out}"
    failed=$((failed + 1))
  fi
}

cloud_init_done() { vm 'cloud-init status --wait' | grep -q 'status: done'; }
active() { vm "systemctl is-active $1"; }
no_packer_user() { ! vm 'id packer' > /dev/null 2>&1; }
sshd_setting() { vm "sudo sshd -T" | grep -qx "$1"; }
password_refused() {
  local out
  out=$(ssh "${ssh_opts[@]}" -o PubkeyAuthentication=no tester@127.0.0.1 true 2>&1) && return 1
  grep -q 'Permission denied (publickey)' <<< "$out"
}
root_refused() { ! ssh "${ssh_opts[@]}" -i "$work/key" root@127.0.0.1 true 2> /dev/null; }
guest_agent() {
  local i
  for i in 1 2 3 4 5 6; do
    # Keep the connection open after the request: QEMU drops it on EOF,
    # before the agent answers.
    { echo '{"execute":"guest-info"}'; sleep 3; } | socat - "UNIX-CONNECT:$work/qga.sock" 2> /dev/null |
      grep -q '"version"' && return 0
    sleep 5
  done
  echo "no answer to guest-info"
  return 1
}
root_grown() {
  local mb
  mb=$(vm "df -B1M --output=size / | tail -n 1" | tr -d ' ')
  ((mb >= min_root_mb)) || { echo "root filesystem is ${mb}M"; return 1; }
}

check "cloud-init finished" cloud_init_done
check "qemu-guest-agent active" active qemu-guest-agent
check "guest agent answers" guest_agent
check "unattended-upgrades active" active unattended-upgrades
check "build user removed" no_packer_user
check "sshd: no root login" sshd_setting 'permitrootlogin no'
check "sshd: no password login" sshd_setting 'passwordauthentication no'
check "password login refused" password_refused
check "root login refused" root_refused
check "root filesystem grown to the disk" root_grown

if ((failed > 0)); then
  echo "$failed check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
