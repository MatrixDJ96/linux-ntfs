#!/bin/bash
# Usage: get-kernel.sh <kernel> <dest>
# Copies the kernel RPMs of <kernel> out of Bazzite's akmods image.
set -euo pipefail
k=$1 dest=$2
fc=$(sed -n 's/.*\.fc\([0-9]*\)\..*/\1/p' <<< "$k")

for tag in "ogc-$fc-$k" "ogc-lts-$fc-$k"; do
	if docker pull -q "ghcr.io/ublue-os/akmods:$tag" > /dev/null 2>&1; then
		c=$(docker create "ghcr.io/ublue-os/akmods:$tag" true)
		docker cp "$c:/kernel-rpms" "$dest"
		ls "$dest"
		exit 0
	fi
done
echo "no akmods image for $k"
exit 1
