# Testing GNU awk (gawk) on OpenVMS

gawk ships its own OpenVMS test driver, `vms/vmstest.com`, maintained upstream alongside
the rest of its VMS port. It runs the upstream test files (`test/*.awk`, `*.in`, `*.ok`)
with DCL, so **no GNV is needed and it runs on IA64 as well as x86-64**. Results are
written as JUnit XML (`test/test_output.xml`).

| Layer | Runs on | Command (host) |
|---|---|---|
| Upstream VMS test suite, 412 tests | IA64, x86-64 | `tools/vmstest.sh <node> [test ...]` |

`tools/vmstest.sh` runs `@[-.VMS]VMSTEST.COM` from `[.TEST]` as a batch job, fetches the
XML and the batch log to `out/vmstest-<node>/`, and summarises them. It deletes earlier
`_*.tmp`, `_*.err` and `_*.too` outputs first: for many tests `vmstest.com` deletes version
`;2` of the new output (a workaround for an SSH quirk), so a leftover `;1` from an earlier
failing run would be compared instead and the test would keep failing.

## Current results (gawk 5.4.1)
| Suite | IA64 | x86-64 |
|---|---|---|
| Upstream VMS test suite (412 tests) | 386 pass, 0 fail, 26 skipped | 388 pass, 0 fail, 24 skipped |

The final full run on each node failed only `beginfile1`, because `tools/push.sh` did not
upload `test/Makefile.in`, which the test reads as a sample file; with it uploaded the test
passes on both nodes.

## Skipped tests
These skips are upstream's own (`vms/vmstest.com`), with upstream's reasons.

| Test | Where | Reason |
|---|---|---|
| getline | both | Requires a Unix shell |
| rand | both | Test detection not implemented yet |
| sigpipe1 | both | Test not supported |
| fflush | both | Not supported |
| getlnhd | both | Expects a Unix shell |
| localenl | both | Not supported |
| poundbang | both | Not supported |
| clos1way | both | Test not supported |
| clos1way2 | both | Test not supported |
| clos1way3 | both | Test not supported |
| clos1way4 | both | Test not supported |
| clos1way5 | both | Test not supported |
| dbugeval | both | Skipped when not on a terminal (batch) |
| devfd | both | Not supported |
| devfd1 | both | Not supported |
| devfd2 | both | Not supported |
| manyfiles | both | Test detection not implemented yet |
| profile2 | both | Verification bug in VMS 9.2-2 EDIT/SUM (access violation) |
| pty1 | both | Not supported |
| strftime | both | Needs GNV coreutils' gnv$date.exe |
| backbigs1 | both | Needs a locale VMS does not ship |
| backsmalls1 | IA64 only | Needs the UTF8-50 locale (IA64 has only UTF8-20) |
| mbprintf5 | IA64 only | Test not currently passing on VMS (UTF-8 issue) |
| double1 | both | Skipped |
| double2 | both | Skipped |
| fmtspcl | both | Not supported |

## What the suite found
Fixed by our patches (see README):
- **Upstream VMS port lag:** `config_h.com` could not handle the multi-line C23 `bool` `#if`
  new in gawk 5.4.1's `configh.in` (nothing compiled); `vmstest.com` still ran `rscompat`
  with `--traditional` (upstream switched it to `--posix` in 2025-07) and the old form of
  `colonwarn`.
- **Program name:** `gawk_name` left the full image path in messages when the device name
  has a node or allocation class prefix (`MYI64$DKA800`, `X86VMS$DKA0`).
- **x86-64 SORT:** `sort sys$input: _longwrds.tmp` writes to `SYS$INPUT:_LONGWRDS.TMP` on
  E9.2, and the failing comparison ended the whole run.
- **IA64 optimiser:** VSI C dropped `if (x == -0) x = 0;`, so `printf "%d", -0.4` printed
  `-0` (`zero2`).
