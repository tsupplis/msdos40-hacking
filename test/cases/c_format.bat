REM Commands: FORMAT, CHKDSK, SYS, COPY, FC on drive B:
REM @blank-b
REM @seconds 150
ECHO == format b:
ECHO.> A:\ANS.TXT
ECHO N>> A:\ANS.TXT
FORMAT B: /V:TESTVOL < A:\ANS.TXT | FIND /V "percent"
ECHO == chkdsk b:
CHKDSK B:
ECHO == sys b:
SYS A: B:
DIR B:
ECHO == copy and compare
COPY A:\COMMAND.COM B:\C2.COM
FC /B A:\COMMAND.COM B:\C2.COM
