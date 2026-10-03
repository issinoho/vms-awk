# CLAUDE.md

Guidance for working in this repository: GNU awk (gawk) for OpenVMS (IA64 and x86-64),
built with **gawk's own upstream VMS port** (`vms/` in the release tarball), wrapped by the
same tooling as `~/projects/vms-grep` and `~/projects/vms-sed`. Read README.md first.

## How this differs from vms-grep / vms-sed

- **No host-side configure.** Upstream's `vms/config_h.com` makes `config.h` on VMS, and
  `vms/descrip.mms` builds. `tools/prepare.sh` only fetches, verifies, patches and overlays,
  and checks that `vms/descrip.mms` lists every source in `Makefile.am`'s `base_sources`.
- **Upstream owns `vms/`.** Our VMS files live in `overlay/vmsport/`. Fix upstream's VMS
  files with patches (they are candidates to send to gawk's VMS maintainer).
- **MMS targets are lower case** (`gawk`, `spotless`) and must be passed unquoted under
  `SET PROCESS/PARSE_STYLE=EXTENDED` (`vmsport/build.com` does this); quoted, MMS rejects them.
- **Tests:** upstream's DCL driver `vms/vmstest.com`, via `tools/vmstest.sh <node> [tests]`;
  no GNV, runs on IA64 too. It deletes version ;2 of outputs, so stale `_*.tmp/.err/.too`
  from an earlier run must be removed first (vmstest.sh does).
- **Release tracking:** each new gawk release brings an updated `vms/`; where it lags (as
  5.4.1's `config_h.com` did), patch it so we still release the same day.

## Ground rules

- **Never edit `staging/`, `cache/` or `out/`.** They are regenerated. Every VMS change is
  either a patch (`patches/NNNN-*.patch`, listed in `patches/series`) or a new file in
  `overlay/`. `tools/prepare.sh` refuses overlay files that would replace upstream files.
- **Change an upstream file with a patch.** Make a pristine copy under `a/` and an edited
  copy under `b/`, run `diff -u a/<path> b/<path>`, and put a `Subject:` line and a short
  explanation above the diff. Guard VMS-only code with `#ifdef __VMS` so the patch could go
  upstream. Patches to the same file stack, so diff against the tree as it stands after the
  earlier patches.
- **Test failures:** before blaming the environment, rerun the case by hand on the node and
  compare with the `.ok` file; record findings in `docs/TESTING.md`. Upstream's skips (in
  `vms/vmstest.com`) carry their own reasons.
- **Committed files must not contain real node details.** Use `<ia64-host>`, `<x86-host>`
  and `DISK$USER:[USERNAME.VMS_GREP]`. The real values live only in the git-ignored
  `tools/nodes.conf`.
- Keep `docs/TESTING.md` and the README status table in step with test results.

## Commands

```sh
tools/prepare.sh                        # always first after changing patches/overlay
tools/build.sh <ia64|x86> [ALL|CLEAN] [KEEP_GOING]
tools/vmstest.sh <node> [tests...]      # upstream's VMS test suite (batch; ~15 min for all)
tools/vms.sh <node> dcl '<cmd>' ...     # run DCL; also run/batch/put/get
tools/kit.sh <node>                     # PCSI kit -> out/kits/ (producer ISSINOHO)  [to come]
tools/installcheck.sh <node>            # install kit, verify, remove (changes system; ask first) [to come]
```

Run long operations (a full build or test run takes 10-20 minutes) with
`run_in_background`. Upstream's descrip.mms tracks headers per object, but after changing
compiler flags run `tools/build.sh <node> CLEAN` (upstream's `spotless`) first.

## VMS and tooling pitfalls (learned the hard way)

- **Use `tools/vms.sh`, never raw `ssh host cmd`.** Raw ssh output is often lost, and
  sessions sometimes never close. vms.sh logs to a file and waits for a completion marker.
- **Never use `WAIT` in DCL run over ssh**; it hangs (batch jobs are fine).
- **Never edit a bash script that is running.** bash reads scripts incrementally. Replace
  long-running tools atomically (write a copy, then `mv`).
- **Don't use `pkill -f` / `pgrep -f`** with a pattern that also matches your own shell's
  command line. Kill by explicit PID. On VMS, stop only processes this session started
  (they are network/batch processes of the work account); leave interactive sessions alone.
- **DCL details:**
  - `F$SEARCH` with a wildcard needs a stream id when other `F$SEARCH` calls happen in the
    same loop.
  - Batch jobs default to `/LIST` and `/MAP`.
  - DCL command lines are limited to about 4096 bytes (hence the wildcard librarian step).
  - `CALL` arguments are upper-cased unless quoted.
  - `SYS$LOGIN:[.X]` is not valid on these nodes.
- **`sftp put -r` into an existing directory nests a copy**; push.sh uploads file by file.
- **Run `tools/prepare.sh` after every change to `patches/` or `overlay/`.** build.sh and
  kit.sh push whatever is in `staging/`; forgetting this once shipped a stale kit.
- **stdout on VMS is often record-oriented** (terminal, `/OUTPUT` log, mailbox). The CRTL
  turns each `fwrite` item into a record (patch 0004 writes with `putc`), and a host-side
  `grep` treats output containing a NUL as binary (use `grep -a`).
- **CRTL quirks** that matter (shared with grep) are documented in
  vms-grep's `docs/vms-environment.md`:
  - no `#include_next`; text-library includes instead;
  - `open()` of a directory fails;
  - `setlocale("")` ignores environment variables;
  - UTF-8 decoding bugs;
  - `mempcpy` is a macro;
  - argument case under traditional parse style.

## Commits

Commit in logical steps with messages that explain the VMS reason for each change. Don't
push without the user asking. The GitHub remote is `origin`
(github.com/issinoho/vms-awk), branch `main`.
