#!/bin/bash
# Usage: build-module.sh <kernel> <src> <rpms> <kroot>
# Builds <src>/ntfs.ko against <kernel> in the Fedora release it was built for, and unpacks
# the kernel and its modules into <kroot> for the VM.
set -euo pipefail
k=$1 src=$2 rpms=$3 kroot=$4
fc=$(sed -n 's/.*\.fc\([0-9]*\)\..*/\1/p' <<< "$k")
# Same flags bazzite-mx builds with (build_files/kmods/ntfsplus/source.env).
args="CONFIG_NTFS_FS=m CONFIG_NTFS_FS_WOF_COMPRESSION=y"

mkdir -p "$kroot"
docker run --rm -v "$src:/src" -v "$rpms:/rpms:ro" -v "$kroot:/kroot" -e K="$k" -e ARGS="$args" \
	"quay.io/fedora/fedora:$fc" bash -euc '
	dnf -q -y install gcc make bc elfutils-libelf-devel cpio > /dev/null 2>&1
	rpms=$(find /rpms -name "*.rpm")
	rpm -i --nodeps --noscripts --nosignature $(grep -E "kernel-devel-[0-9]" <<< "$rpms")
	cd /kroot
	for p in kernel-core kernel-modules; do
		for f in $(grep -E "/$p-[0-9]" <<< "$rpms"); do
			rpm2cpio "$f" | cpio -idm --quiet
		done
	done
	make -C "/usr/src/kernels/$K" M=/src $ARGS modules -j"$(nproc)"
	ls -l /src/ntfs.ko
'
