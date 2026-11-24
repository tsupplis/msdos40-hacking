_TEXT segment byte public 'CODE'
assume cs:_TEXT,ds:_TEXT
CR equ 13
LF equ 10
include showhelp.inc
_TEXT ends
end
