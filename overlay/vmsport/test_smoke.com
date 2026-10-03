$! TEST_SMOKE.COM - quick functional check of a built or installed GAWK.EXE
$!
$! Usage:  @[.VMSPORT]TEST_SMOKE [gawk-image]
$!         The default image is GAWK.EXE at the top of this tree.
$! Exits with SS$_NORMAL if every test passes, otherwise reports failures.
$!
$ set noon
$ on control_y then goto finish
$ saved_default = f$environment("DEFAULT")
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ set process/parse_style=extended
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ image = p1
$ if image .eqs. "" then image = f$parse("GAWK.EXE")
$ if f$search(image) .eqs. ""
$ then
$   write sys$error "SMOKE: no image ''image'"
$   exit 44
$ endif
$ gawk := $'image'
$ pass == 0
$ fail == 0
$ if f$search("SMOKE_TMP.DIR") .eqs. "" then create/directory [.SMOKE_TMP]
$ set default [.SMOKE_TMP]
$ if f$search("*.*;*") .nes. "" then delete/nolog *.*;*
$ create fruit.txt
apple 3
Banana 5
cherry 7
$ open/write fsf fs.txt
$ write fsf "a,b,c"
$ close fsf
$! (A data line must not start with "$", or DCL takes it as a command.)
$ create prog.awk
{ if ($1 ~ /an/) n++ }
END { print n }
$ call t version  0 ""                 "--version"
$ call t sum      0 "15"               """{ s += $2 } END { print s }"" fruit.txt"
$ call t fields   0 "3 cherry"         """END { print NR, $1 }"" fruit.txt"
$ call t printf   0 "42 VMS 3.14"      """BEGIN { printf """"%d %s %.2f\n"""", 42, substr(""""OpenVMS"""", 5), atan2(0, -1) }"""
$ call t toupper  0 "APPLE"            """NR == 1 { print toupper($1) }"" fruit.txt"
$ call t regex    0 "Banana"           """/^[A-Z]/ { print $1 }"" fruit.txt"
$ call t gsub     0 "b_n_n_"           """NR == 2 { gsub(/a/, """"_""""); print tolower($1) }"" fruit.txt"
$ call t split    0 "3:b"              """BEGIN { n = split(""""a,b,c"""", x, """",""""); print n """":"""" x[2] }"""
$ call t assoc    0 "2"                """{ seen[length($1) > 5] = 1 } END { print length(seen) }"" fruit.txt"
$ call t progfile 0 "1"                "-f prog.awk fruit.txt"
$ call t fs       0 "b"                """-F,"" ""{ print $2 }"" fs.txt"
$ call t exitcode 3 ""                 """BEGIN { exit 3 }"""
$ call t nofile   2 ""                 """{ print }"" no_such_file.txt"
$ call t badprog  1 ""                 """BEGIN { print ("""
$!
$! Output to a record-oriented destination (a PIPE mailbox): each line one record.
$ pipe gawk "{ print NR "": "" $1 }" fruit.txt | search/nooutput sys$pipe "2: Banana"/exact
$ if $severity .eq. 1
$ then
$   write sys$output "PASS PIPE-RECORDS"
$   pass == pass + 1
$ else
$   write sys$output "FAIL PIPE-RECORDS"
$   fail == fail + 1
$ endif
$!
$! A pipe from an awk program to a DCL command.
$ define/user sys$output out.txt
$ gawk "BEGIN { print ""zz"" | ""sort sys$input: sys$disk:[]sorted.txt""; print ""aa"" | ""sort sys$input: sys$disk:[]sorted.txt"" }"
$ got = ""
$ if f$search("sorted.txt") .eqs. "" then goto pipe_check
$ open/read sf sorted.txt
$ read/end=pipe_check sf got
$ close sf
$pipe_check:
$ if got .eqs. "aa"
$ then
$   write sys$output "PASS PRINT-TO-COMMAND"
$   pass == pass + 1
$ else
$   write sys$output "FAIL PRINT-TO-COMMAND: [", got, "]"
$   fail == fail + 1
$ endif
$!
$finish:
$ set default 'vmsdir'
$ set default [-]
$ set process/parse_style='saved_parse'
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed (''image')"
$ set default 'saved_default'
$ if fail .eq. 0 .and. pass .gt. 0 then exit 1
$ exit 44
$!
$! --- T name expected-exit expected-output args -------------------------
$t: subroutine
$ set noon
$ if f$search("out.txt") .nes. "" then delete/nolog out.txt;*
$ define/user sys$output out.txt
$! gawk opens SYS$OUTPUT and SYS$ERROR separately: sharing one file gives two
$! versions, and the newest (stderr) would be read.  Only stdout is compared.
$ define/user sys$error nla0:
$ gawk 'p4'
$ st = $status
$ code = (st .and. %X7F8) / 8
$! A gawk exit status of 0 can arrive as a plain VMS success.
$ if st .and. code .eq. 0 then code = 0
$ got = ""
$ if f$search("out.txt") .eqs. "" then goto compare
$ open/read f out.txt
$readloop:
$ read/end=readdone f line
$ if got .nes. "" then got = got + "|"
$ got = got + line
$ if f$length(got) .gt. 200 then goto readdone
$ goto readloop
$readdone:
$ close f
$compare:
$ ok = code .eq. f$integer(p2)
$ if p1 .nes. "VERSION" .and. p2 .eq. 0 then ok = ok .and. (got .eqs. p3)
$ if p1 .eqs. "VERSION" then ok = ok .and. (f$locate("GNU Awk", got) .lt. f$length(got))
$ if ok
$ then
$   write sys$output "PASS ", p1
$   pass == pass + 1
$ else
$   write sys$output "FAIL ", p1, ": exit ", code, " (want ", p2, "), output [", got, "] (want [", p3, "])"
$   fail == fail + 1
$ endif
$ exit 1
$ endsubroutine
