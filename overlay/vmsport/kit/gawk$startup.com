$! GAWK$STARTUP.COM - system startup for GNU awk on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! GAWK$ROOT, pointing at the installed [GAWK] directory.  To run it at every
$! boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:GAWK$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign GAWK$ROOT instead (PCSI runs it so at removal).
$!
$! Users then define the gawk and awk commands with
$!     $ @GAWK$ROOT:[000000]GAWK$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("GAWK$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode GAWK$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[GAWK].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.GAWK.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "GAWK.]"
$ if root .eqs. dir + "GAWK.]"
$ then
$   write sys$error "GAWK$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed GAWK$ROOT 'dev''root'
$ if f$search("GAWK$ROOT:[BIN]GAWK.EXE") .eqs. ""
$ then
$   write sys$error "GAWK$STARTUP: GAWK.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for GNU awk"
$ say ""
$ say "    At system startup: to define GAWK$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:GAWK$STARTUP.COM"
$ say "    For each user: to define the gawk and awk commands, add this line to LOGIN.COM:"
$ say "    $ @GAWK$ROOT:[000000]GAWK$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE GAWK removes the product and deassigns GAWK$ROOT."
$ say ""
$ exit 1
