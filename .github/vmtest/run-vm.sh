#!/bin/bash
# Usage: run-vm.sh <group> <kernel-root> <kernel> <ntfs.ko> <variant> <root.raw> <tests.txt>
#                  <out-dir>
# Boots <kernel> with <ntfs.ko> installed under updates/, runs one test group (compression,
# file-dir or xfstests) and saves the serial console to <out-dir>/<group>.log. Fails if the
# group didn't finish, loaded another module or failed a test.
set -euo pipefail
group=$1 kroot=$2 k=$3 ko=$4 variant=$5 root=$6 tests=$7 out=$8
here=$(dirname "$(realpath "$0")")
run=$out/$group
log=$out/$group.log

mkdir -p "$run/t/lib/modules" "$run/disk"
cp -a "$kroot/lib/modules/$k" "$run/t/lib/modules/"
rm -f "$run/t/lib/modules/$k/kernel/fs/ntfs/ntfs.ko"*
install -Dm644 "$ko" "$run/t/lib/modules/$k/updates/ntfs.ko"
depmod -b "$run/t" "$k"
mv "$run/t/lib/modules" "$run/disk/modules"
LC_ALL=C readelf -n "$ko" | awk '/Build ID/ {print $3}' > "$run/disk/buildid"
echo "$variant" > "$run/disk/variant"
echo "$group" > "$run/disk/group"
cp "$here/vm-tests.sh" "$tests" "$run/disk/"
truncate -s 2G "$run/run.img"
mkfs.ext4 -q -F -d "$run/disk" "$run/run.img"

qemu-system-x86_64 -enable-kvm -cpu host -m 6G -smp "$(nproc)" \
	-display none -monitor none -no-reboot \
	-kernel "$run/disk/modules/$k/vmlinuz" \
	-append "root=/dev/vda rw console=ttyS0 init=/vmtest panic=-1" \
	-drive file="$root",if=virtio,format=raw \
	-drive file="$run/run.img",if=virtio,format=raw,readonly=on \
	-serial file:"$log" &
vm=$!
tail --pid="$vm" -n +1 -F "$log" 2> /dev/null | grep --line-buffered '^VMTEST' || true
wait "$vm" || true
rm -rf "$run"

line=$(grep -m1 '^VMTEST module ' "$log" | tr -d '\r' || true)
if ! grep -q '^VMTEST DONE' "$log"; then
	echo "$group did not finish"
	exit 1
elif [ -z "$line" ] || [ "$(awk '{print $5}' <<< "$line")" != "$(awk '{print $7}' <<< "$line")" ]
then
	echo "$group loaded another module: $line"
	exit 1
elif grep -qE '^VMTEST (FAIL|FATAL)' "$log"; then
	echo "$group failed: $(grep -E '^VMTEST (FAIL|FATAL)' "$log" | tr -d '\r' | cut -d' ' -f3- \
		| tr '\n' ' ')"
	exit 1
fi
