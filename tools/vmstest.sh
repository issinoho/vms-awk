#!/usr/bin/env bash
# vmstest.sh <node> [list] - run gawk's own VMS test driver ([.VMS]VMSTEST.COM,
# maintained upstream) as a batch job on <node>, then fetch its JUnit results.
# list defaults to "all".  No GNV is needed, so it runs on IA64 too.
# Output: out/vmstest-<node>/test_output.xml, batch.log, summary.txt
set -euo pipefail
top=$(cd "$(dirname "$0")/.." && pwd)
node=${1:?usage: vmstest.sh <node> [list]}
list=${2:-all}
. "$top/upstream.conf"
remote=$(echo "$UPSTREAM_NAME-$UPSTREAM_VERSION" | tr . _)
REMOTE=$(echo "$remote" | tr a-z A-Z)
read -r _ _ _ _ _ WORKDIR _ < <(awk -v n="$node" '$1==n' "$top/tools/nodes.conf")

job=$top/cache/vmstest-$node.com
cat > "$job" <<DCL
\$ set noon
\$ set process/parse_style=extended
\$ set default ${WORKDIR%]}.$REMOTE.TEST]
\$ @[-.VMS]VMSTEST.COM $list
DCL
dest=$top/out/vmstest-$node
rm -rf "$dest"; mkdir -p "$dest"
VMS_BATCH_POLL_SECS=60 VMS_BATCH_POLLS=300 "$top/tools/vms.sh" "$node" batch "$job" > "$dest/batch.log" 2>&1 || true
"$top/tools/vms.sh" "$node" get "$remote/test/test_output.xml" "$dest/test_output.xml" >/dev/null 2>&1 || true
python3 - "$dest/test_output.xml" > "$dest/summary.txt" <<'PY'
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception as e:
    print("no parsable test_output.xml:", e); sys.exit(0)
cases = root.iter('testcase')
n = f = s = 0; bad = []; skipped = []
for c in cases:
    n += 1
    if c.find('failure') is not None or c.find('error') is not None:
        f += 1; bad.append(c.get('name'))
    elif c.find('skipped') is not None:
        s += 1; skipped.append(c.get('name'))
print("SUMMARY: tests=%d pass=%d fail=%d skip=%d" % (n, n - f - s, f, s))
if bad: print("FAILED:", " ".join(bad))
if skipped: print("SKIPPED:", " ".join(skipped))
PY
cat "$dest/summary.txt"
