#!/usr/bin/env bash
# prepare.sh - build a VMS-ready gawk source tree in staging/<name>-<version>/
#
#   1. fetch + verify the upstream tarball
#   2. extract it, apply patches/series, lay overlay/ over the top
#
# gawk ships its own OpenVMS port (vms/: descrip.mms, config_h.com, vms_*.c,
# vmstest.com), maintained upstream and updated with every release, so unlike
# vms-grep/vms-sed there is no host-side configure: the VMS build generates
# config.h itself.  Our own VMS files live in vmsport/ (upstream owns vms/).
#
# Nothing in staging/ is ever edited by hand: fix things in patches/ or overlay/.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"
name=$UPSTREAM_NAME-$UPSTREAM_VERSION
tarball=$top/cache/$(basename "$UPSTREAM_URL")
stage=$top/staging/$name

step() { echo "prepare: $*"; }
die() { echo "prepare: error: $*" >&2; exit 1; }

"$top/tools/fetch.sh" >/dev/null

step "extracting $name"
rm -rf "$stage"; mkdir -p "$top/staging"
tar -xJf "$tarball" -C "$top/staging"
[ -d "$stage" ] || die "tarball did not unpack to $stage"

while read -r p; do
    case $p in ''|'#'*) continue ;; esac
    step "patch $p"
    patch -d "$stage" -p1 -s --no-backup-if-mismatch -F0 < "$top/patches/$p" ||
        die "patch $p does not apply cleanly"
done < "$top/patches/series"

# overlay/ may only add files; changes to upstream files belong in patches/.
(cd "$top/overlay" && find . -type f) | while read -r f; do
    [ -e "$stage/$f" ] && die "overlay/$f would replace an upstream file; use a patch"
    true
done
cp -a "$top/overlay/." "$stage/"

# Every source the Unix build compiles must be in upstream's VMS build too:
# a release whose vms/descrip.mms misses a new source would not link.
unix=$(awk '/^base_sources *=/,/^$/' "$stage/Makefile.am" | tr ' \t\\' '\n\n\n' |
       sed -n 's/\.c$//p' | LC_ALL=C sort -u)
vms=$(grep -oiE '[a-z_]+\.obj' "$stage/vms/descrip.mms" | tr A-Z a-z | sed 's/\.obj$//' | LC_ALL=C sort -u)
missing=$(LC_ALL=C comm -23 <(echo "$unix") <(echo "$vms"))
[ -z "$missing" ] || die "vms/descrip.mms lacks sources the Unix build uses: $missing"
step "vms/descrip.mms covers all $(echo "$unix" | wc -l) core sources"

printf 'VERSION=%s\nKIT_VERSION=%s-vms%s\n' "$UPSTREAM_VERSION" "$UPSTREAM_VERSION" \
    "$VMS_PATCH_LEVEL" > "$stage/vmsport/version.env"
step "staged $stage"
