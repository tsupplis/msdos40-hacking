@echo off
echo setting up system to build the MS-DOS 4.01 SOURCE BAK...
set CL=
set LINK=
set MASM=
set COUNTRY=usa-ms
set BAKROOT=e:
rem BAKROOT points to the home drive/directory of the sources.
x-masm6
set LIB=%BAKROOT%\src\tools\lib
set INIT=%BAKROOT%\src\tools
set INCLUDE=%BAKROOT%\src\tools\inc
set PATH=%PATH%;%BAKROOT%\src\tools
