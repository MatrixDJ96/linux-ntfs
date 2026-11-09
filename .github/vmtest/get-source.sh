#!/bin/bash
# Usage: get-source.sh <bazzite-mx|ntfs-next> <harness> <dest>
# bazzite-mx is this checkout; ntfs-next is plain ntfs-next.
set -euo pipefail
variant=$1 harness=$2 dest=$3

if [ "$variant" = bazzite-mx ]; then
	cp -a "$harness" "$dest"
else
	git clone -q --depth 1 --branch ntfs-next https://github.com/namjaejeon/linux-ntfs "$dest"
fi
git -C "$dest" log -1 --format='%H %s'
