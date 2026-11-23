 page 80,132
;	SCCSID = @(#)tcmd1a.asm 1.1 85/05/14
;	SCCSID = @(#)tcmd1a.asm 1.1 85/05/14
TITLE	PART4 COMMAND Transient routines.

;	Internal commands DIR,PAUSE,ERASE,TYPE,VOL,VER

	INCLUDE comsw.asm
.xlist
.xcref
	INCLUDE DOSSYM.INC
	INCLUDE comseg.asm
	INCLUDE comequ.asm		;AC000;
	include sysmsg.inc
	include ioctl.inc		;AN000;
.list
.cref

DATARES SEGMENT PUBLIC BYTE		;AN020;
	EXTRN	append_flag:byte	;AN020;
	EXTRN	append_state:word	;AN020;
DATARES ENDS				;AN020;

TRANDATA	SEGMENT PUBLIC BYTE	;AC000;
	EXTRN	BadCD_ptr:word
	extrn DirDateFormat:byte, dir_short_year:byte
	extrn dir_attrs:byte,dir_ordered:byte,dir_replay:byte
	EXTRN	bits:word
	EXTRN	Bytmes_ptr:word
	EXTRN	comsw:word
	extrn	dir_l_syn:byte,dir_b_syn:byte
tree_all db '*.*',0
DirNoPause equ 0400h
	EXTRN	dir_w_syn:word		;AC000;
	EXTRN	dirdat_mo_day:word	;AC000;
	EXTRN	dirdat_yr:word		;AC000;
	EXTRN	dirdattim_ptr:word
	EXTRN	dirhead_ptr:word,dirhead_path:word
	EXTRN	dirtim_hr_min:word	;AC000;
	extrn tree_stats_ptr:word,tree_total_ptr:word

	EXTRN	disp_file_size_ptr:word
	EXTRN	Dmes_ptr:word
	EXTRN	Extend_buf_ptr:word	;AN000;
	EXTRN	msg_disp_class:byte	;AN000;
	EXTRN	parse_dir:byte		;AC000;
	EXTRN	slash_p_syn:word	;AC000;
	EXTRN	string_buf_ptr:word
	EXTRN	tab_ptr:word		;AC000;
TRANDATA	ENDS

TRANSPACE	SEGMENT PUBLIC BYTE	;AC000;
        extrn bwdbuf:byte
; Last visited child (ASCIIZ) and path end per level. A single DTA
; suffices because child names are visited in lexical order.
; The 64-character DOS directory limit permits at most 32 one-letter names.
tree_frames db 33*15 dup (?)
tree_best db 13 dup (?)
tree_frame dw ?
tree_path db 82 dup (?)
tree_mask db 13 dup (?)
tree_entry db 43 dup (?)
tree_fcb db 37 dup (?)
tree_seen db ?
public tree_count_arg
tree_count_arg dw 2 dup (?)
tree_size dw 2 dup (?)
total_count dw 2 dup (?)
total_size dw 2 dup (?)
	EXTRN	bytes_free:word
	EXTRN	charbuf:byte
	EXTRN	COM:byte
	EXTRN	Destisdir:byte
	EXTRN	Desttail:word

	EXTRN	Dirbuf:byte
	EXTRN	dirflag:byte		;AN015;
	EXTRN	display_ioctl:word	;AC000;
	EXTRN	display_mode:byte	;AC000;
	EXTRN	filecnt:word
	EXTRN	file_size_high:word
	EXTRN	file_size_low:word
	EXTRN	fullscr:word
	EXTRN	ID:byte
	EXTRN	lincnt:byte		;AC000;
	EXTRN	linlen:byte
	EXTRN	linperpag:word		;AC000;
	EXTRN	msg_numb:word		;AN022;
	EXTRN	parse1_addr:dword	;AC000;
	EXTRN	parse1_syn:word 	;AC000;
	EXTRN	parse1_type:byte	;AC000;
	EXTRN	pathcnt:word		;AN000;
	EXTRN	pathpos:word		;AN000;
	EXTRN	resseg:word		;AN020;
	EXTRN	srcbuf:byte		;AC000;
	EXTRN	string_ptr_2:word
TRANSPACE	ENDS

TRANCODE	SEGMENT PUBLIC BYTE

ASSUME	CS:TRANGROUP,DS:NOTHING,ES:NOTHING,SS:NOTHING

;---------------

TRANSPACE	SEGMENT PUBLIC BYTE	;AC000;
	EXTRN	arg:byte		; the arg structure!
TRANSPACE	ENDS
;---------------

	EXTRN	cerror:near
	EXTRN	std_printf:near


	PUBLIC	catalog


	break	Catalog - Directory command
assume	ds:trangroup,es:trangroup

;
; The DIR command displays the contents of a directory.
;
; ****************************************************************
; *
; * ROUTINE:	 CATALOG - display file(s) in directory
; *
; * FUNCTION:	 PARSE command line for drive, file, or path name.
; *		 DIR allows two switches, /P (pause) and /W (wide).
; *		 If an error occurs issue and error message and
; *		 transfer control to CERROR.
; *
; * INPUT:	 command line at offset 81H
; *
; * OUTPUT:	 none
; *
; ****************************************************************

CATALOG:
 invoke dir_options
 jnc catalog_start
 mov ax,BadSwt_ptr
 invoke setup_parse_error_msg
 jmp cerror
catalog_start:

;
; Set up DTA for dir search firsts
;
	mov	dx,offset trangroup:Dirbuf	;AC000; Set Disk transfer address
	mov	ah,Set_DMA			;AC000;
	int	int_command			;AC000;
;
; Set up defaults for switches and parse the command line.
;
	mov	msg_numb,0			;AN022; initialize message flag
	mov	di,offset trangroup:srcbuf	;AN000; get address of srcbuf
	mov	[pathpos],di			;AN000; this is start of path
	mov	[pathcnt],1			;AN000; initialize length to 1 char
	mov	al,star 			;AN000; initialize srcbuf to *,0d
	stosb					;AN000;
	mov	al,end_of_line_in		;AN000;
	stosb					;AN000;
	mov	si,81H				;AN000; Get command line
	mov	di,offset trangroup:parse_dir	;AN000; Get adderss of PARSE_DIR
	xor	cx,cx				;AC000; clear counter for positionals
	mov	ComSw,cx			;AC000; initialize flags
	mov	linperpag,linesperpage		;AC000; Set default for lines per page
	mov	linlen,normperlin		;AC000; Set number of entries per line
	mov	lincnt,normperlin		;AC000;

dirscan:
	xor	dx,dx				;AN000;
	invoke	parse_with_msg			;AC018; call parser
	cmp	ax,end_of_line			;AN000; are we at end of line?
	jne	dirscan_cont			;AN000; No - continue parsing
	jmp	scandone			;AN000; yes - go process

dirscan_cont:
	cmp	ax,result_no_error		;AN000; did we have an error?
	jz	dirscan_cont2			;AN000; No - continue parsing
	jmp	badparm 			;AN000; yes - exit

dirscan_cont2:
	push	si				;AC000; save position in line
	lds	si,parse1_addr			;AC000; get address of filespec
	push	si				;AN000; save address
	invoke	move_to_srcbuf			;AC000; move to srcbuf
	pop	dx				;AC000; get address in DX

;
; The user may have specified a device.  Search for the path and see if the
; attributes indicate a device.
;
	mov	ah,Find_First			;AC000; find the file
	int	int_command			;AC000;
	jnc	Dir_check_device		;AN022; if no error - check device
	invoke	get_ext_error_number		;AN022; get the extended error
	cmp	ax,error_no_more_files		;AN022; was error no file found
	jz	Dir_fspec_end			;AC022; yes -> obviously not a device
	cmp	ax,error_path_not_found 	;AN022; was error no file found
	jz	Dir_fspec_end			;AC022; yes -> obviously not a device
	jmp	dir_err_setup			;AN022; otherwise - go issue error message

dir_check_device:				;AN022;
	test	byte ptr (DirBuf+find_buf_attr),attr_device ;AC000;
	jz	Dir_fspec_end			;AC000; no, go do normal operation
	mov	ComSw,-2			;AC000; signal device

dir_fspec_end:
	pop	si				;AC000; restore position in line
	jmp	dirscan			;AC000; keep parsing

ScanDone:
 test bits,SwitchW
 jz check_paging
	mov	linlen,wideperlin		;AC000; Set number of entries per line
	mov	lincnt,wideperlin		;AC000;
check_paging:
 test bits,SwitchP
 jz dir_path_setup
	push	cx				;AN000; save necessary registers
	push	si				;AN000;
	mov bx,stdout
	mov ax,IOCTL SHL 8
	int int_command
	jc no_dir_paging
	test dl,devid_ISDEV
	jz no_dir_paging
	test dl,devid_ISNUL
	jnz no_dir_paging
	test dl,devid_ISCOT             ; CTTY sets this on its selected handle
	jz no_dir_paging
	mov	ax,(IOCTL SHL 8) + generic_ioctl_handle ;AN000; get lines per page on display
	mov	bx,stdout			;AN000; lines for stdout
	mov	ch,ioc_sc			;AN000; type is display
	mov	cl,get_generic			;AN000; get information
	mov	dx,offset trangroup:display_ioctl ;AN000;
	int	int_command			;AN000;

	jmp short lines_set
no_dir_paging:
	or bits,DirNoPause
lines_set:
	dec	linperpag			;AN000; lines per actual page should
	dec	linperpag			;AN000;     two less than the max
	mov	ax,linperpag			;AN000; get number of lines into
	mov	[fullscr],ax			;AC000;    screen line counter
	pop	si				;AN000; restore registers
	pop	cx				;AN000;
 jmp short dir_path_setup
BadParm:
 jmp cerror
dir_path_setup:
	; A leading switch may occupy the default PSP FCB. Use the parsed path.
	mov	si,offset trangroup:srcbuf
	mov	di,FCB
	mov	ax,Parse_File_Descriptor SHL 8
	int	int_command

;
; Find and display the volume ID on the drive.
;

	test	bits,DirBare
	jz	dir_volume
	; OKVOLARG normally seeds the default *.* search mask.
	mov	di,FCB+1
	mov	cx,11
	mov	al,'?'
	rep	stosb
	jmp	short dir_volume_done
dir_volume:
	invoke	okvolarg
dir_volume_done:			;AC000;
	mov     tree_size,0
        mov     tree_size+2,0
	mov	[filecnt],0			;AC000; Keep track of how many files found
	cmp	comsw,0 			;AC000; did an error occur?
	jnz	doheader			;AC000; yes - don't bother to fix path

	mov	dirflag,-1			;AN015; set pathcrunch called from DIR
	invoke	pathcrunch			;AC000; set up FCB for dir
	mov	dirflag,0			;AN015; reset dirflag
	jc	DirCheckPath			;AC015; no CHDIRs worked.
	jz	doheader			;AC015; chdirs worked - path\*.*
	mov	si,[desttail]			;AN015; get filename back
	jmp	short DoRealParse		;AN015; go parse it

DirCheckPath:
	mov	ax,[msg_numb]			;AN022; get message number
	cmp	ax,0				;AN022; Is there a message?
	jnz	dir_err_setup			;AN022; yes - there's an error
	cmp	[destisdir],0			;AC000; Were pathchars found?
	jz	doparse 			;AC000; no - no problem
	inc	comsw				;AC000; indicate error
	jmp	short doheader			;AC000; go print header

DirNF:
	mov	ax,error_file_not_found 	;AN022; get message number in control block

dir_err_setup:
	mov	msg_disp_class,ext_msg_class	;AN000; set up extended error msg class
	mov	dx,offset TranGroup:Extend_Buf_ptr  ;AC000; get extended message pointer
	mov	extend_buf_ptr,ax		;AN022;

DirError:
	jmp	Cerror

;
; We have changed to something.  We also have a file.  Parse it into a
; reasonable form, leaving drive alone, leaving extention alone and leaving
; filename alone.  We need to special case ...	If we are at the root, the
; parse will fail and it will give us a file not found instead of file not
; found.
;
DoParse:
	mov	si,offset trangroup:srcbuf	;AN000; Get address of source
	cmp	byte ptr [si+1],colon_char	;AN000; Is there a drive?
	jnz	dir_no_drive			;AN000; no - keep going
	lodsw					;AN000; bypass drive

dir_no_drive:
	cmp	[si],".."
	jnz	DoRealParse
	cmp	byte ptr [si+2],0
	jnz	DoRealParse
	inc	ComSw
	jmp	short DoHeader

DoRealParse:
	mov	di,FCB			; where to put the file name
	mov	ax,(Parse_File_Descriptor SHL 8) OR 0EH
	int	int_command

;
; Check to see if APPEND installed.  If it is installed, set all flags
; off.	This will be reset in the HEADFIX routine
;

DoHeader:
	mov	ax,AppendInstall		;AN020; see if append installed
	int	2fh				;AN020;
	cmp	al,0				;AN020; append installed?
	je	DoHeaderCont			;AN020; no - continue
	mov	ax,AppendDOS			;AN020; see if append DOS version right
	int	2fh				;AN020;
	cmp	ax,-1				;AN020; append version correct?
	jne	DoHeaderCont			;AN020; no - continue
	mov	ax,AppendGetState		;AN020; Get the state of Append
	int	2fh				;AN020;
	push	ds				;AN020; save current data segment
	mov	ds,[resseg]			;AN020; get resident segment
	assume	ds:resgroup			;AN020;
	mov	append_state,bx 		;AN020; save append state
	mov	append_flag,-1			;AN020; set append flag
	xor	bx,bx				;AN020; clear out state
	mov	ax,AppendSetState		;AN020; Set the state of Append
	int	2fh				;AN020;     set everything off
	pop	ds				;AN020; save current data segment
	assume	ds:trangroup			;AN020;

;
; Display the header
;

DoHeaderCont:
        test bits,DirTree
        jz single_header
        cmp ComSw,0
        jne single_header
        jmp tree_start
single_header:
	test	bits,DirBare
	jnz	dir_header_done
	mov	al,blank			;AN051; Print out a blank
	invoke	print_char			;AN051;   before DIR header
	invoke	build_dir_string		; get current dir string
        mov dirhead_path,offset trangroup:bwdbuf
	mov	dx,offset trangroup:Dirhead_ptr
	invoke	printf_crlf			; bang!

;
; If there were chars left after parse or device, then invalid file name
;
dir_header_done:
	cmp	ComSw,0
	jz	DoSearch			; nothing left; good parse
	jl	DirNFFix			; not .. => error file not found
	invoke	RestUDir
	mov	dx,offset TranGroup:BadCD_ptr
	jmp	Cerror				; was .. => error directory not found
DirNFFix:
	invoke	RestUDir
	jmp	DirNF
;
; We are assured that everything is correct.  Let's go and search.  Use
; attributes that will include finding directories.  perform the first search
; and reset our directory afterward.
;
DoSearch:
	mov	byte ptr DS:[FCB-7],0FFH
	mov byte ptr DS:[FCB-1],attr_directory
 cmp dir_attrs,0
 je search_mask_ready
 or byte ptr DS:[FCB-1],attr_hidden+attr_system
search_mask_ready:
;
; Caution!  Since we are using an extended FCB, we will *also* be returning
; the directory information as an extended FCB.  We must bias all fetches into
; DIRBUF by 8 (Extended FCB part + drive)
;
	mov	ah,Dir_Search_First
	mov	dx,FCB-7
	int	int_command

	push	ax				;AN022; save return state
	inc	al				;AN022; did an error occur?
	pop	ax				;AN022; get return state back
	jnz	found_first_file		;AN022; no error - start dir
	invoke	set_ext_error_msg		;AN022; yes - set up error message
	push	dx				;AN022; save message
	invoke	restudir			;AN022; restore user's dir
	pop	dx				;AN022; restore message
	cmp	word ptr Extend_Buf_Ptr,Error_No_More_Files ;AN022; convert no more files to
	jnz	DirCerrorJ			;AN022; 	file not found
	mov	Extend_Buf_Ptr,Error_File_Not_Found  ;AN022;

DirCerrorJ:					;AN022;
	jmp	Cerror				;AN022; exit

;
; Restore the user's directory.  We preserve, though, the return from the
; previous system call for later checking.
;

found_first_file:
	push	ax
	invoke	restudir
	pop	ax
;
; Main scanning loop.  Entry has AL = Search first/next error code.  Test for
; no more.
;
DIRSTART:
	inc	al				; FF = file not found
	jnz	Display
	jmp	DirDone 			; Either an error or we are finished
;
; Note that we've seen a file and display the found file.
;

Display:
 cmp dir_attrs,0
 je entry_selected
 invoke dir_matches
 jz entry_selected
 jmp scroll
entry_selected:
 cmp dir_ordered,0
 je print_entry
 invoke dir_collect
 jnc entry_saved
 mov ax,error_not_enough_memory
 jmp dir_err_setup
entry_saved:
 jmp scroll
print_entry:
        test bits,DirTree
        jz entry_ready
        test bits,DirBare
        jz tree_has_entry
        cmp byte ptr dirbuf+8,'.'
        jne tree_has_entry
        jmp scroll
tree_has_entry:
        mov tree_seen,1
        add total_count,1
        adc total_count+2,0
        test [dirbuf+8].dir_attr,attr_directory
        jnz tree_check_header
        mov ax,[dirbuf+8].dir_size_l
        mov dx,[dirbuf+8].dir_size_h
        add total_size,ax
        adc total_size+2,dx
tree_check_header:
        cmp filecnt,0
        jne entry_ready
        test bits,DirBare
        jnz entry_ready
        mov bx,tree_frame
        mov di,[bx+13]
        cmp di,offset trangroup:tree_path+3
        je tree_heading_end
        dec di
tree_heading_end:
        mov byte ptr [di],0
        mov dirhead_path,offset trangroup:tree_path
        mov dx,offset trangroup:Dirhead_ptr
        push di
        call std_printf
        call tree_line
        invoke crlf2
        call tree_line
        pop di
        mov byte ptr [di],5ch
entry_ready:
        test [dirbuf+8].dir_attr,attr_directory
        jnz counted_size
        mov ax,[dirbuf+8].dir_size_l
        mov dx,[dirbuf+8].dir_size_h
        add tree_size,ax
        adc tree_size+2,dx
counted_size:
	inc	[filecnt]			; Keep track of how many we find
	mov	si,offset trangroup:dirbuf+8	; SI -> information returned by sys call
	test	bits,DirBare
	jz	dir_full_entry
	cmp	byte ptr [si],dot_chr
	jne	dir_bare_name
	jmp	scroll
dir_bare_name:
        test bits,DirTree
        jz bare_leaf
        mov si,offset trangroup:tree_path
        mov di,offset trangroup:charbuf
        mov bx,tree_frame
        mov cx,[bx+13]
        sub cx,si
        rep movsb
        mov si,offset trangroup:dirbuf+8
        jmp short bare_convert
bare_leaf:
	mov	di,offset trangroup:charbuf
bare_convert:
	invoke	fcb_to_ascz
	call	dir_print_name
	jmp	dir_end_line
dir_full_entry:
	call	shoname
;
; If we are displaying in wide mode, do not output the file info
;
	test	byte ptr[bits],SwitchW		; W switch set?
	jz	DirTest
	jmp	nexent				; If so, no size, date, or time

;
; Test for directory.
;
DirTest:
	test	[dirbuf+8].dir_attr,attr_directory
	jz	fileent
;
; We have a directory.	Display the <DIR> field in place of the file size
;
	mov	dx,offset trangroup:Dmes_ptr
	call	std_printf
	jmp	short nofsiz
;
; We have a file.  Display the file size
;
fileent:
	mov	dx,[DirBuf+8].dir_size_l
	mov	file_size_low,dx
	mov	dx,[DirBuf+8].dir_size_h
	mov	file_size_high,dx
	mov	dx,offset trangroup:disp_file_size_ptr
	call	std_printf
;
; Display time and date of last modification
;
nofsiz:
	mov	ax,[DirBuf+8].dir_date		; Get date
;
; If the date is 0, then we have found a 1.x level diskette.  We skip the
; date/time fields as 1.x did not have them.
;
	or	ax,ax
	jz	nexent				; Skip if no date
	mov	bx,ax
	and	ax,1FH				; get day
	mov	dl,al
	mov	ax,bx
	mov	cl,5
	shr	ax,cl				; Align month
	and	al,0FH				; Get month
	mov	dh,al
	mov	cl,bh
	shr	cl,1				; Align year
	xor	ch,ch
	mov	DirDateFormat,Right_Align+DATE_MDY_4
	add	cx,1980
	cmp	dir_short_year,0
	je	millenium
	mov	DirDateFormat,Right_Align+DATE_MDY_2
	mov	ax,cx
	mov	cl,100
	div	cl				; AH = last two digits, including FAT years after 2099
	mov	cl,ah
	xor	ch,ch

millenium:
	xchg	dh,dl				;AN000; switch month & day
	mov	DirDat_yr,cx			;AC000; put year into message control block
	mov	DirDat_mo_day,dx		;AC000; put month and day into message control block
	mov	cx,[DirBuf+8].dir_time		; Get time
	jcxz	prbuf				; Time field present?
	shr	cx,1
	shr	cx,1
	shr	cx,1
	shr	cl,1
	shr	cl,1				; Hours in CH, minutes in CL
	xchg	ch,cl				;AN000; switch hours & minutes
	mov	DirTim_hr_min,cx		;AC000; put hours and minutes into message subst block

prbuf:
	mov	dx,offset trangroup:DirDatTim_ptr
	call	std_printf
dir_end_line:
	invoke	crlf2				;AC066;end the line
	dec	byte ptr [fullscr]		;AC066;count the line
	jnz	endif04 			;AN066;IF the last on the screen THEN
	   call    check_for_P			;AN066;   pause if /P requested
	endif04:				;AN066;
	jmp	scroll				; If not, just continue
;AD061; mov	DirDat_yr,0			;AC000; reset year, month and day
;AD061; mov	DirDat_mo_day,0 		;AC000;     in control block
;AD061; mov	DirTim_hr_min,0 		;AC000; reset hour & minute in control block
;
; We are done displaying an entry.  The code between "noexent:" and "scroll:"
; is only for /W case.
;
nexent:
	mov	bl,[lincnt]			;AN066;save for check for first entry on line
	dec	[lincnt]			      ;count this entry on the line
	jnz	else01				;AX066;IF last entry on line THEN
	   mov	   al,[linlen]
	   mov	   [lincnt],al
	   invoke  crlf2
	   cmp	   [fullscr],0			;AC066;IF have filled the screen THEN
	   jnz	   endif02			;AN066;
	      call    check_for_P		;AN066;   reinitialize fullscr,
	   endif02:				;AN066;   IF P requested THEN pause
	   jmp	   short endif01		;AN066;
	else01: 				;AN066;ELSE since screen not full
	   cmp	   bl,[linlen]			;AN066;   IF starting new line THEN
	   jne	   endif03			;	     count the line
	      dec     byte ptr [fullscr]	;AN066;   ENDIF
	   endif03:				;AC066;We are outputting on the same line, between fields, we tab.
	   mov	   dx,offset trangroup:tab_ptr	;Output a tab
	   call    std_printf
	endif01:				;AX066;
;
; All we need to do now is to get the next directory entry.
;
scroll:
 cmp dir_replay,0
 je search_next_entry
 invoke dir_take
 jc sorted_end
 jmp print_entry
sorted_end:
 jmp listing_end
search_next_entry:
        test bits,DirTree
        jz single_next
        mov ah,4fh
        jmp tree_search
single_next:
	mov	ah,Dir_Search_Next
	mov	dx,FCB-7			; DX -> Unopened FCB
	int	int_command			; Search for a file to match FCB
	jmp	DirStart
;
; If no files have been found, display a not-found message
;
DirDone:
	invoke	get_ext_error_number		;AN022; get the extended error number
	cmp	ax,error_no_more_files		;AN022; was error file not found?
	jnz	dir_err_setup_jmp		;AN022; no - setup error message
 cmp dir_ordered,0
 je listing_end
 invoke dir_sort
 jmp scroll
listing_end:
        test bits,DirTree
        jz single_end
        jmp tree_children
single_end:
	test	[filecnt],-1
	jnz	Trailer
	mov	ax,error_file_not_found 	;AN022;

dir_err_setup_jmp:				;AN022;
	jmp	dir_err_setup			;AN022; go setup error msg & print it
;
; If we have printed the maximum number of files per line, terminate it with
; CRLF.
;
Trailer:
	test	bits,DirBare
	retnz
	mov	al,[linlen]
	cmp	al,[lincnt]			; Will be equal if just had CR/LF
	jz	mmessage
	invoke	crlf2
	cmp	[fullscr],0			;AN066;IF on last line of screen THEN
	jnz	endif06 			;AN066;   pause before going on
	   call    check_for_P			;AN066;   to number and freespace
	endif06:				;AN066;   displays

mmessage:
        mov ax,filecnt
        mov tree_count_arg,ax
        mov tree_count_arg+2,0
        mov ax,tree_size
        mov dx,tree_size+2
        test bits,DirTree
        jz single_stats
        jmp tree_stats
single_stats:
        call tree_stats
dir_free_space:
	mov	ah,Get_Drive_Freespace
	mov	dl,byte ptr DS:[FCB]
	int	int_command
	cmp	ax,-1
	retz
	mul	cx				; AX is bytes per cluster
	mul	bx
	mov	bytes_free,ax			;AC000;
	mov	bytes_free+2,dx 		;AC000;
	MOV	DX,OFFSET TRANGROUP:BYTMES_ptr
	jmp	std_printf

 ; Keep file selection and child enumeration independent. All handle searches
 ; use absolute paths so output, paging and interrupts see the user's cwd.
tree_start:
        invoke build_dir_string
        mov si,offset trangroup:bwdbuf
        mov di,offset trangroup:tree_path
tree_root_copy:
        lodsb
        stosb
        or al,al
        jnz tree_root_copy
        dec di
        cmp di,offset trangroup:tree_path+3
        je tree_root_ready
        mov al,5ch
        stosb
tree_root_ready:
        mov bx,offset trangroup:tree_frames
        mov tree_frame,bx
        mov [bx+13],di
        mov si,FCB+1
        mov di,offset trangroup:tree_mask
        invoke fcb_to_ascz
        invoke restudir
        mov tree_seen,0
        xor ax,ax
        mov total_count,ax
        mov total_count+2,ax
        mov total_size,ax
        mov total_size+2,ax
tree_node:
        mov bx,tree_frame
        mov byte ptr [bx],0
        invoke dir_reset_sort
        mov tree_size,0
        mov tree_size+2,0
        mov filecnt,0
        mov al,linlen
        mov lincnt,al
        mov si,offset trangroup:tree_mask
        call tree_spec
        mov dx,offset trangroup:tree_entry
        mov ah,1ah
        int int_command
        mov cx,attr_directory
        cmp dir_attrs,0
        je tree_first
        or cl,attr_hidden+attr_system
tree_first:
        mov dx,offset trangroup:tree_path
        mov ah,4eh
tree_search:
        int int_command
        jnc tree_found
        cmp ax,error_file_not_found
        je tree_exhausted
        cmp ax,error_no_more_files
        je tree_exhausted
        jmp dir_err_setup
tree_exhausted:
        cmp dir_ordered,0
        je tree_children
        invoke dir_sort
        jmp scroll
tree_found:
        mov si,offset trangroup:tree_entry+30
        mov di,offset trangroup:tree_fcb
        mov ax,2900h
        int int_command
        cmp tree_entry+30,'.'
        jne tree_name_ok
        mov tree_fcb+1,'.'
        cmp tree_entry+31,'.'
        jne tree_name_ok
        mov tree_fcb+2,'.'
tree_name_ok:
        mov si,offset trangroup:tree_fcb+1
        mov di,offset trangroup:dirbuf+8
        mov cx,11
        rep movsb
        mov al,tree_entry+21
        stosb
        mov si,offset trangroup:tree_entry+22
        mov di,offset trangroup:dirbuf+8+22
        movsw
        movsw
        mov di,offset trangroup:dirbuf+8+28
        movsw
        movsw
        jmp Display

tree_children:
        test bits,DirBare
        jnz tree_child_first
        cmp filecnt,0
        je tree_child_first
        call Trailer
tree_child_first:
        mov si,offset trangroup:tree_all
        call tree_spec
        mov tree_best,0
        mov dx,offset trangroup:tree_entry
        mov ah,1ah
        int int_command
        mov cx,attr_directory
        mov dx,offset trangroup:tree_path
        mov ah,4eh
tree_child_search:
        int int_command
        mov bx,tree_frame
        jc tree_scan_end
        test tree_entry+21,attr_directory
        jz tree_next
        cmp tree_entry+30,'.'
        je tree_next
        mov si,offset trangroup:tree_entry+30
        mov di,bx
        call tree_compare
        jbe tree_next
        mov di,offset trangroup:tree_best
        cmp byte ptr [di],0
        je tree_candidate
        call tree_compare
        jae tree_next
tree_candidate:
        mov cx,13
        rep movsb
tree_next:
        mov ah,4fh
        jmp short tree_child_search
tree_scan_end:
        cmp ax,error_no_more_files
        je tree_choose
        cmp ax,error_file_not_found
        je tree_choose
        jmp dir_err_setup
tree_choose:
        cmp tree_best,0
        je tree_pop
        mov di,bx
        mov si,offset trangroup:tree_best
        mov cx,13
        rep movsb
        mov di,[bx+13]
        mov si,bx
tree_child_copy:
        lodsb
        or al,al
        jz tree_child_ready
        cmp di,offset trangroup:tree_path+66
        jb tree_child_byte
        jmp tree_child_first
tree_child_byte:
        stosb
        jmp short tree_child_copy
tree_child_ready:
        mov al,5ch
        stosb
        add bx,15
        mov tree_frame,bx
        mov [bx+13],di
        jmp tree_node
tree_pop:
        cmp bx,offset trangroup:tree_frames
        je tree_finish
        sub bx,15
        mov tree_frame,bx
        jmp tree_child_first
; Compare two DOS ASCIIZ names, preserving both pointers and returning flags.
tree_compare:
        push si
        push di
tree_compare_byte:
        lodsb
        scasb
        jne tree_compared
        or al,al
        jnz tree_compare_byte
tree_compared:
        pop di
        pop si
        ret
tree_finish:
        mov dx,offset trangroup:dirbuf
        mov ah,1ah
        int int_command
        cmp tree_seen,0
        jne tree_return
        jmp DirNF
tree_return:
        test bits,DirBare
        retnz
        mov dx,offset trangroup:tree_total_ptr
        call std_printf
        call tree_line
        mov ax,total_count
        mov tree_count_arg,ax
        mov ax,total_count+2
        mov tree_count_arg+2,ax
        mov ax,total_size
        mov dx,total_size+2
        call tree_stats
        jmp dir_free_space
tree_stats:
        mov file_size_low,ax
        mov file_size_high,dx
        mov dx,offset trangroup:tree_stats_ptr
        call std_printf
tree_line:
        test bits,SwitchP
        retz
        dec fullscr
        jz tree_pause
        ret
tree_pause:
        jmp check_for_P
tree_spec:
        mov bx,tree_frame
        mov di,[bx+13]
tree_spec_copy:
        lodsb
        stosb
        or al,al
        jnz tree_spec_copy
        ret

shoname:
	mov	di,offset trangroup:charbuf
        test    bits,SwitchW
        jz      dir_fcb_field
        test    [si].dir_attr,attr_directory
        jz      dir_fcb_field
        mov     al,'['
        stosb
        invoke  fcb_to_ascz
        mov     byte ptr [di-1],']'     ; Replace the name terminator.
        ; The existing tab advances to column 16 once eight bytes are printed.
        mov     al,' '
dir_wide_pad:
        cmp     di,offset trangroup:charbuf+8
        jae     dir_wide_done
        stosb
        jmp     dir_wide_pad
dir_wide_done:
        mov     byte ptr [di],0
        jmp     short dir_print_name
dir_fcb_field:
	mov	cx,8
	rep	movsb
	mov	al,' '
	stosb
	mov	cx,3
	rep	movsb
	xor	ax,ax
	stosb
dir_print_name:
	test	bits,DirLower
	jz	dir_name_ready
	mov	si,offset trangroup:charbuf
dir_lower_loop:
	lodsb
	or	al,al
	jz	dir_name_ready
	invoke	testkanj
	jz	dir_single_byte
	inc	si
	jmp	dir_lower_loop
dir_single_byte:
	cmp	al,'A'
	jb	dir_lower_loop
	cmp	al,'Z'
	ja	dir_lower_loop
	or	byte ptr [si-1],20h
	jmp	dir_lower_loop
dir_name_ready:
	push	dx
	mov	dx,offset trangroup:charbuf
	mov	string_ptr_2,dx
	mov	dx,offset trangroup:string_buf_ptr
	call	std_printf
	pop	DX
	return

check_for_P    PROC  NEAR			;AN066;

test bits,DirNoPause
jnz endif05
test	byte ptr[bits],SwitchP	     ;P switch present?
jz	endif05 				;AN066;
   mov	   ax,linperpag 		   ;AN000;  transfer lines per page
   mov	   [fullscr],ax 		   ;AC000;	to fullscr
   invoke  Pause
endif05:
ret						;AN066;

check_for_P    ENDP				;AN066;

trancode    ends
	    end
