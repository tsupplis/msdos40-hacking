REM Driver: ANSI.SYS must show up in the device list
MEM /DEBUG
CTTY CON
ANSICURS
IF ERRORLEVEL 1 GOTO FAIL
CTTY COM1
ECHO PASS ANSI cursor movement and position report
GOTO DONE
:FAIL
CTTY COM1
ECHO FAILED ANSI cursor movement or position report
:DONE
