$! GAWK$SETUP.COM - define the gawk and awk commands for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @GAWK$ROOT:[000000]GAWK$SETUP.COM
$!
$! Quote awk programs and upper-case options, or SET PROCESS/PARSE_STYLE=EXTENDED:
$! traditional DCL parsing changes the case of unquoted arguments.
$!
$ if f$trnlnm("GAWK$ROOT") .eqs. ""
$ then
$   write sys$error "GAWK$SETUP: GAWK$ROOT is not defined; run GAWK$STARTUP.COM first"
$   exit 44
$ endif
$ gawk :== $GAWK$ROOT:[BIN]GAWK.EXE
$ awk  :== $GAWK$ROOT:[BIN]GAWK.EXE
$ exit 1
