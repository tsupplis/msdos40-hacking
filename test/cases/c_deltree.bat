REM @blank-b
md A:\WIN30
echo keep>A:\WIN30\KEEP.TXT
echo N>A:\NO.TXT
A:\DELTREE.EXE WIN30 <A:\NO.TXT
if not exist A:\WIN30\KEEP.TXT echo FAILED declined deletion
subst D: A:\WIN30
if not exist D:\KEEP.TXT echo FAILED SUBST setup
A:\DELTREE.EXE /Y WIN30
if not errorlevel 1 echo FAILED SUBST guard status
if not exist A:\WIN30\KEEP.TXT echo FAILED SUBST guard
subst D: /D
A:\DELTREE.EXE /Y WIN30
if errorlevel 1 echo FAILED deletion status
if exist A:\WIN30\NUL echo FAILED target still exists
A:\DELTREE.EXE
if not errorlevel 1 echo FAILED missing operand
A:\DELTREE.EXE /x
if not errorlevel 1 echo FAILED invalid switch
A:\DELTREE.EXE /y .
if not errorlevel 1 echo FAILED dot
A:\DELTREE.EXE /y ..
if not errorlevel 1 echo FAILED parent
A:\DELTREE.EXE /y A:\
if not errorlevel 1 echo FAILED root
A:\DELTREE.EXE /y NOFILE.ZZZ
if not errorlevel 1 echo FAILED missing target
md A:\WIN30
md A:\WIN30\CHILD
echo keep>A:\WIN30\CHILD\KEEP.TXT
cd A:\WIN30\CHILD
A:\DELTREE.EXE /y A:\WIN30
if not errorlevel 1 echo FAILED ancestor status
if not exist KEEP.TXT echo FAILED ancestor removed
cd A:\
A:\DELTREE.EXE /y WIN30
if exist A:\WIN30\NUL echo FAILED recursive deletion
