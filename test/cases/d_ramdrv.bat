REM Driver: RAMDRIVE.SYS 64 KB becomes drive C:, copy a file in and compare it
CHKDSK C:
COPY A:\AUTOEXEC.BAT C:\T.BAT
FC /B A:\AUTOEXEC.BAT C:\T.BAT
DIR C:
