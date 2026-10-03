$! BUILD.COM - build GNU awk (gawk) for OpenVMS with upstream's own VMS port
$!
$! Usage:  @[.VMSPORT]BUILD [target] [KEEP_GOING]
$!         target defaults to GAWK; CLEAN runs upstream's SPOTLESS target.
$!         KEEP_GOING carries on past failed compiles.
$!
$! gawk ships its OpenVMS build in [.VMS] (DESCRIP.MMS, CONFIG_H.COM, ...),
$! maintained upstream and updated with every release; this procedure only
$! runs it from the top of the tree.  Output: GAWK.EXE in the top directory.
$!
$ status = 44  ! SS$_ABORT unless the build runs
$ on control_y then goto done
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ target = f$edit(p1, "UPCASE")
$ if target .eqs. "" .or. target .eqs. "ALL" then target = "GAWK"
$ if target .eqs. "CLEAN" then target = "SPOTLESS"
$ write sys$output "BUILD: ''target' for ''arch' in ''f$environment("DEFAULT")'"
$ mmsq = ""
$ if p2 .eqs. "KEEP_GOING" then mmsq = "/IGNORE=ERROR"
$! Upstream's target names are lower case (gawk, spotless) and MMS matches
$! them exactly: pass the name unquoted under extended parsing (quoted, MMS
$! rejects it).
$ mmstarget = f$edit(target, "LOWERCASE")
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ set process/parse_style=extended
$ mms/description=[.vms]descrip.mms'mmsq' 'mmstarget'
$ status = $status
$ set process/parse_style='saved_parse'
$ if status then write sys$output "BUILD: done"
$done:
$ set default 'saved_default'
$ exit status
