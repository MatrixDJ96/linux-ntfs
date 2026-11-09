#!/bin/bash
# Runs one c-cpp.yml test group inside the VM and prints one VMTEST line per result.
# PID 1 gets no PATH from the kernel, and mkfs(8) needs one to find mkfs.ntfs.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
group=$(cat /kmod/group)
hostname vmtest
# generic/131 and generic/571 connect to localhost; docker export leaves /etc/hosts empty.
ip link set lo up
echo "127.0.0.1 localhost" > /etc/hosts
mkdir -p /lib/modules && mount --bind /kmod/modules /lib/modules
echo "VMTEST kernel $(uname -r) variant $(cat /kmod/variant) group $group"
modprobe loop max_loop=32
for i in 20 21 22; do
	[ -e /dev/loop$i ] || mknod /dev/loop$i b 7 $i
done
# Boot messages (CPU mitigations on the runner) are not the module's.
dmesg -C
modprobe ntfs || echo "VMTEST FATAL modprobe ntfs"
buildid=$(od -An -tx1 -j16 /sys/module/ntfs/notes/.note.gnu.build-id | tr -d ' \n')
echo "VMTEST module $(modinfo -n ntfs) buildid $buildid want $(cat /kmod/buildid)"
cd /root || exit 1

compression() {
	if bash /src/ci-scripts/run-compression-tests.sh > /tmp/comp.log 2>&1; then
		echo "VMTEST PASS compression"
	else
		echo "VMTEST FAIL compression"
		tail -20 /tmp/comp.log
	fi
}

file_dir() {
	if (
		set -e
		truncate -s 10G /root/full.img
		losetup /dev/loop22 /root/full.img
		mkfs.ntfs -q /dev/loop22 > /dev/null
		mkdir -p /mnt/full
		mount -t ntfs /dev/loop22 /mnt/full
		cd /mnt/full
		for i in $(seq 1 10000); do touch file$i; done
		sync
		cd /
		umount /mnt/full
		mount -t ntfs /dev/loop22 /mnt/full
		cd /mnt/full
		rm -rf ./*
		for i in $(seq 1 10000); do mkdir file$i; done
		sync
		rm -rf ./*
		cd /
		umount /mnt/full
		ntfsck -n /dev/loop22
	) > /tmp/full.log 2>&1; then
		echo "VMTEST PASS file-dir"
	else
		echo "VMTEST FAIL file-dir"
		tail -20 /tmp/full.log
	fi
	losetup -d /dev/loop22
	rm -f /root/full.img
}

fresh_volumes() {
	umount /mnt/test /mnt/scratch 2> /dev/null
	mkfs.ntfs -q -f /dev/loop20 > /dev/null
	mkfs.ntfs -q -f /dev/loop21 > /dev/null
}

passes() {
	./check "$1" > /tmp/t.log 2>&1 < /dev/null && grep -q 'Passed all 1 tests' /tmp/t.log
}

warnings='ntfs.*(error|corrupt|bug)|BUG:|WARNING:|Oops|blocked for more than'

xfstests() {
	truncate -s 100G /root/test.img /root/scratch.img
	losetup /dev/loop20 /root/test.img
	losetup /dev/loop21 /root/scratch.img
	fresh_volumes
	cd /src/exfat-testsuites/xfstests-exfat || exit 1
	# A failed test can leave a broken volume behind, so recreate both and try it once more.
	# RETRY means it only passed the second time.
	# tests.txt comes from c-cpp.yml: test names, plus the directories it empties in between.
	while read -r t; do
		if [ -d "$t" ]; then
			rm -rf "${t:?}"/*
		elif passes "$t"; then
			echo "VMTEST PASS $t"
		elif grep -q 'Not run' /tmp/t.log; then
			echo "VMTEST NOTRUN $t"
		else
			grep -A6 'output mismatch\|_check' /tmp/t.log | head -8 > /tmp/first.log
			dmesg | grep -iE "$warnings" | head -10 | sed 's/^/VMTEST RETRYDMESG /'
			dmesg -C
			fresh_volumes
			if passes "$t"; then
				echo "VMTEST RETRY $t"
			else
				echo "VMTEST FAIL $t"
				fresh_volumes
			fi
			cat /tmp/first.log
		fi
	done < /kmod/tests.txt
}

case $group in
	compression) compression ;;
	file-dir) file_dir ;;
	xfstests) xfstests ;;
	*) echo "VMTEST FATAL unknown group $group" ;;
esac

dmesg | grep -iE "$warnings" | head -20 | sed 's/^/VMTEST DMESG /'
echo "VMTEST DONE"
sync
echo o > /proc/sysrq-trigger
sleep 30
