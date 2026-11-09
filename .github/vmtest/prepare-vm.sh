#!/bin/bash
# Usage: prepare-vm.sh <harness> <workdir>
# Builds the VM root filesystem (<workdir>/root.raw) with xfstests and ntfsprogs-plus, lists the
# c-cpp.yml tests in <workdir>/tests.txt and installs QEMU.
set -euo pipefail
harness=$1 w=$2
ctx=$w/ctx

mkdir -p "$ctx/src"
cp "$harness/.github/vmtest/Dockerfile" "$ctx/"
cp "$harness/.github/vmtest/vm-init.sh" "$ctx/src/"
cp -a "$harness/.github/scripts" "$ctx/src/ci-scripts"
git clone -q --depth 1 https://github.com/namjaejeon/exfat-testsuites "$ctx/src/exfat-testsuites"
git clone -q --depth 1 --branch ntfs-next https://github.com/ntfsprogs-plus/ntfsprogs-plus \
	"$ctx/src/ntfsprogs-plus"
docker build -q -t vmroot "$ctx"
mkdir "$w/rootfs"
docker export "$(docker create vmroot)" | sudo tar -x -C "$w/rootfs" --exclude='dev/*'
truncate -s 260G "$w/root.raw"
sudo mkfs.ext4 -q -F -d "$w/rootfs" "$w/root.raw"
sudo chown "$USER" "$w/root.raw"

# Test names, plus the directories c-cpp.yml empties in between.
sed -n -e 's|^ *sudo ./check \(generic/[0-9]*\)$|\1|p' \
	-e 's|^ *rm -rf \(/mnt/[a-z]*\)/\*$|\1|p' \
	"$harness/.github/workflows/c-cpp.yml" > "$w/tests.txt"
want=$(grep -c './check generic/' "$harness/.github/workflows/c-cpp.yml")
got=$(grep -c '^generic/' "$w/tests.txt")
if [ "$want" -eq 0 ] || [ "$got" -ne "$want" ]; then
	echo "c-cpp.yml runs $want xfstests, $got parsed"
	exit 1
fi
echo "$got xfstests"

echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
	| sudo tee /etc/udev/rules.d/99-kvm.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
sudo apt-get -qq update
sudo apt-get -qq install -y qemu-system-x86 > /dev/null
