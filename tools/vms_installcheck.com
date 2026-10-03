$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the gawk kit, verify, smoke-test the
$! installed image, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[GAWK], system logical GAWK$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ tree = f$environment("DEFAULT") - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$ write sys$output "=== INSTALL from ", kitdir
$ product install GAWK /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
$ write sys$output "=== install status ", $status
$ product show product GAWK /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:GAWK$STARTUP.COM"), "]"
$ show logical GAWK$ROOT
$ directory/nohead/notrail GAWK$ROOT:[000000...]*.*
$ @GAWK$ROOT:[000000]GAWK$SETUP.COM
$ show symbol gawk
$ show symbol awk
$ gawk --version
$ create inst_test.txt
alpha
Beta
$ write sys$output "awk (traditional parse style):"
$ set process/parse_style=traditional
$ awk "/Beta/ { print toupper($1) }" inst_test.txt
$ delete/nolog inst_test.txt;*
$ write sys$output "=== SMOKE TEST on installed image"
$ smoke = tree - "]" + ".VMSPORT]TEST_SMOKE.COM"
$ @'smoke' GAWK$ROOT:[BIN]GAWK.EXE
$ write sys$output "=== REMOVE"
$ product remove GAWK /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "GAWK$ROOT after removal: [", f$trnlnm("GAWK$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[GAWK...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:GAWK$STARTUP.COM"), "]"
$ product show product GAWK /producer=ISSINOHO
$ delete/symbol/global gawk
$ delete/symbol/global awk
