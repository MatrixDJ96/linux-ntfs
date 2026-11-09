#!/bin/bash
# Usage: compare-results.sh <dir> <kernel version>...
# Compares our run with the ntfs-next run on each kernel. Fails if a test group didn't finish,
# loaded the wrong module, failed a test ntfs-next passed, or logged a kernel warning. A test
# that passed on its retry counts as passed; errors from its first try are ignored unless they
# are a BUG, a WARNING or a hang.
set -euo pipefail
dir=$1
shift
rc=0
groups="compression file-dir xfstests"

results() {
	cat "$1"/*.log | grep -E '^VMTEST (PASS|RETRY|FAIL|NOTRUN) ' | tr -d '\r' \
		| awk '{print $3, ($2 == "RETRY" ? "PASS" : $2)}' | sort || true
}

for k in "$@"; do
	ours=$dir/bazzite-mx-$k
	base=$dir/ntfs-next-$k
	echo "== $k"
	for run in "$ours" "$base"; do
		for g in $groups; do
			log=$run/$g.log
			if [ ! -f "$log" ] || ! grep -q '^VMTEST DONE' "$log"; then
				echo "FAIL: $log did not finish"
				rc=1
				continue
			fi
			line=$(grep -m1 '^VMTEST module ' "$log" | tr -d '\r' || true)
			got=$(awk '{print $5}' <<< "$line")
			want=$(awk '{print $7}' <<< "$line")
			if [ -z "$got" ] || [ "$got" != "$want" ]; then
				echo "FAIL: $log loaded build id '$got', built '$want'"
				rc=1
			fi
		done
		[ -d "$run" ] || continue
		all=$(cat "$run"/*.log | tr -d '\r')
		echo "$(basename "$run"): $(grep -c '^VMTEST PASS ' <<< "$all") pass," \
			"$(grep -c '^VMTEST FAIL ' <<< "$all") fail," \
			"$(grep -c '^VMTEST RETRY ' <<< "$all") passed on retry:" \
			"$(grep '^VMTEST RETRY ' <<< "$all" | awk '{print $3}' | tr '\n' ' ')"
	done
	[ -d "$ours" ] && [ -d "$base" ] || continue
	regressions=$(join <(results "$base" | awk '$2 == "PASS"') \
		<(results "$ours" | awk '$2 != "PASS"') | awk '{print $1}') || true
	if [ -n "$regressions" ]; then
		echo "FAIL: bazzite-mx fails what ntfs-next passes:" $regressions
		rc=1
	fi
	hard='BUG:|WARNING:|Oops|blocked for more than'
	if cat "$ours"/*.log | grep -E "^VMTEST DMESG |^VMTEST RETRYDMESG .*($hard)"; then
		echo "FAIL: kernel warnings in bazzite-mx"
		rc=1
	fi
done
exit $rc
