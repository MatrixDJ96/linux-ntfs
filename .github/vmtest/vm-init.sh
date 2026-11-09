#!/bin/bash
# Init of the test VM: mount the run disk and start the tests on it.
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mkdir -p /dev/pts /run /tmp /kmod
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /tmp
mount -o ro /dev/vdb /kmod && exec /bin/bash /kmod/vm-tests.sh
echo "VMTEST FATAL no run disk"
echo o > /proc/sysrq-trigger
