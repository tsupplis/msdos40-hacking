REM Commands: BACKUP, RESTORE, REPLACE (B: is a freshly formatted floppy)
REM @seconds 90
ECHO == backup
BACKUP A:\*.SYS B: < A:\CR.TXT
DIR B:
ECHO == restore
DEL A:\ANSI.SYS
RESTORE B: A:\ANSI.SYS < A:\CR.TXT
DIR A:\ANSI.SYS
ECHO == replace
REPLACE A:\AUTOEXEC.BAT B:\ /A
DIR B:\AUTOEXEC.BAT
