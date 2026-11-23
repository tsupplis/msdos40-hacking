; DIR selection and ordering. Sorted entries occupy the shell's existing TPA.
; Each record uses three paragraphs: a FAT entry and its original ordinal.
include comsw.asm
.xlist
include DOSSYM.INC
include comequ.asm
include comseg.asm
.list

TRANDATA segment public byte
public dir_short_year
dir_short_year db ?
public dir_attrs, dir_ordered, dir_replay
extrn bits:word
dircmd_name db 'DIRCMD='
reading_defaults db ?
seen_simple dw ?
simple_names db 'PWBLS'
simple_masks dw SwitchP,SwitchW,DirBare,DirLower,DirTree
dir_attrs db ?
dir_ordered db ?
dir_replay db ?
required_attr db ?
excluded_attr db ?
sort_keys db 5 dup (?)             ; N,E,S,D,G, optional high bit reverses key
key_count db ?
records dw ?
cursor dw ?
gap dw ?
outer_index dw ?
left_seg dw ?
sort_end dw ?
right_seg dw ?
attr_names db 'RHSDA'
attr_bits db 1,2,4,10h,20h
order_names db 'NESDG'
TRANDATA ends
TRANSPACE segment public byte
extrn dirbuf:byte,tpa:word,tran_tpa:word,switchar:byte,parse_last:word
TRANSPACE ends
TRANCODE segment public byte
assume cs:trangroup,ds:trangroup,es:trangroup
public dir_options,dir_matches,dir_collect,dir_sort,dir_take

; Consume compact /A and /O modifiers before the positional system parser.
; Replacing consumed bytes with spaces preserves the offsets of other tokens.
public dir_reset_sort
dir_reset_sort proc near
 mov records,0
 mov cursor,0
 mov dir_replay,0
 ret
dir_reset_sort endp

dir_options proc near
	xor	ax,ax
	mov	dir_short_year,al
	mov	dir_attrs,al
	mov	dir_ordered,al
	mov	dir_replay,al
	mov	records,ax
	mov	cursor,ax
 mov bits,ax
 mov si,offset trangroup:dircmd_name
 invoke get_cmd_defaults
 jc dir_defaults_error
 mov reading_defaults,1
 call scan_dir_options
 jc dir_defaults_error
 mov reading_defaults,0
 mov si,81h
 call scan_dir_options
dir_defaults_error:
 ret
dir_options endp

scan_dir_options proc near
 mov seen_simple,0
option_scan:
	lodsb
	cmp	al,13
	jne	option_char
	clc
	ret
option_char:
 cmp al,switchar
 je option_switch
 cmp reading_defaults,0
 je skip_path_byte
 dec si
 call dir_separator
 jne invalid_default
 inc si
 jmp option_scan
invalid_default:
 inc si
 mov parse_last,si
 dec parse_last
 stc
 ret
skip_path_byte:
 invoke testkanj
 jz option_scan
 inc si
 jmp option_scan
option_switch:
 mov parse_last,si
 dec parse_last
 xor bx,bx
 cmp byte ptr [si],'-'
 jne option_letter
 inc si
 inc bh
option_letter:
 cmp byte ptr [si],13
 jne read_option
 stc
 ret
read_option:
 lodsb
 cmp al,'2'
 jne option_single
 lodsb
 and al,0dfh
 cmp al,'Y'
 jne simple_error
 mov al,1
 sub al,bh
 mov dir_short_year,al
 mov dh,'Y'
 jmp short plain_end
option_single:
 and al,0dfh
 mov dh,al
 mov di,offset trangroup:simple_names
 mov cx,5
 repne scasb
 jne complex_switch
 mov di,4
 sub di,cx
 shl di,1
 mov ax,simple_masks[di]
 or bh,bh
 jnz disable_simple
 test ax,SwitchP+SwitchW
 jz enable_simple
 test seen_simple,ax
 jnz simple_error
enable_simple:
 or bits,ax
 or seen_simple,ax
 jmp short plain_end
disable_simple:
 not ax
 and bits,ax
 and seen_simple,ax
 jmp short plain_end
complex_switch:
 cmp dh,'A'
 je check_attr
 cmp dh,'O'
 jne simple_error
 or bh,bh
 jz enable_order
 mov dir_ordered,0
 jmp short plain_end
check_attr:
 or bh,bh
 jz option_attr
 mov dir_attrs,0
plain_end:
 mov al,[si]
 cmp al,switchar
 je plain_ok
 cmp al,13
 je plain_ok
 call dir_separator
 jne simple_error
plain_ok:
 jmp option_end
simple_error:
 stc
 ret
enable_order:
	mov	dir_ordered,1
	mov	key_count,0
	jmp	short option_list
option_attr:
	mov	dir_attrs,1
	mov	required_attr,0
	mov	excluded_attr,0
option_list:
	cmp	byte ptr [si],':'
	jne	option_key
	inc	si
option_key:
	mov	al,[si]
	cmp	al,13
	je	option_end
	call	dir_separator
	je	option_end
	cmp	al,switchar
	je	option_end
	xor	dl,dl
	cmp	al,'-'
	jne	positive_key
	mov	dl,80h
	inc	si
positive_key:
	mov	al,[si]
	and	al,0dfh
	mov	di,offset trangroup:order_names
	cmp	dh,'O'
	je	find_key
	mov	di,offset trangroup:attr_names
find_key:
	mov	cx,5
	repne	scasb
	jne	options_bad
	inc	si
	cmp	dh,'O'
	je	save_order
	mov	bx,4
	sub	bx,cx
	mov	al,attr_bits[bx]
	or	dl,dl
	jnz	exclude_key
	or	required_attr,al
	jmp	option_key
exclude_key:
	or	excluded_attr,al
	jmp	option_key
save_order:
	xor	bx,bx
	mov	bl,key_count
	cmp	bl,5
	jae	options_bad
	or	al,dl
	mov	sort_keys[bx],al
	inc	key_count
	jmp	option_key
option_end:
	mov	di,parse_last
	mov	cx,si
	sub	cx,di
	mov	al,' '
	rep	stosb
	cmp	dh,'O'
	jne	scan_more
 cmp dir_ordered,0
 je scan_more
	cmp	key_count,0
	jne	scan_more
	mov	word ptr sort_keys,'NG'        ; directories first, then names
	mov	key_count,2
scan_more:
	jmp	option_scan
options_bad:
	cmp	byte ptr [si],13
	je	option_error
	inc	si
option_error:
	stc
	ret
scan_dir_options endp

; Normalize the system parser's two-byte space in the writable input.
dir_separator proc near
 cmp al,' '
 je separator_done
 cmp al,9
 je separator_done
 cmp al,','
 jne check_dbcs_space
 mov byte ptr [si],' '
 ret
check_dbcs_space:
 cmp word ptr [si],4081h
 jne separator_done
 mov word ptr [si],2020h
separator_done:
 ret
dir_separator endp

; ZF set if all requested attributes match.
dir_matches proc near
	mov	al,[dirbuf+8].dir_attr
	test	al,excluded_attr
	jnz	matches_done
	and	al,required_attr
	cmp	al,required_attr
matches_done:
	ret
dir_matches endp

; AX = record index; return its segment in AX.
record_segment proc near
	mov	dx,ax
	shl	ax,1
	add	ax,dx
	add	ax,tpa
	ret
record_segment endp

dir_collect proc near
	cmp	records,0
	jne	have_sort_end
 ; The largest TPA allocation can be below other allocated blocks.
 ; Stop at either its MCB limit or the transient command code.
	mov	ax,tran_tpa
	dec	ax
	push	es
	mov	es,ax
	mov	dx,es:[3]
	pop	es
	add	dx,tran_tpa
	mov	ax,cs
	cmp	dx,ax
	jbe	use_sort_end
	mov	dx,ax
use_sort_end:
	mov	sort_end,dx
have_sort_end:
	mov	ax,records
	call	record_segment
	mov	dx,sort_end
	sub	dx,3
	cmp	ax,dx
	ja	collect_full
	push	es
	mov	es,ax
	xor	di,di
	mov	si,offset trangroup:dirbuf+8
	mov	cx,16
	rep	movsw
	mov	ax,records
	stosw
	pop	es
	inc	records
	clc
	ret
collect_full:
	stc
	ret
dir_collect endp

; Compare ES:0 (left) with DS:0 (right). Carry means right precedes left.
; All sort metadata belongs to the transient group, addressed via CS.
compare_entries proc near
	xor	bx,bx
key_loop:
	cmp	bl,cs:key_count
	je	compare_ordinal
	mov	al,cs:sort_keys[bx]
	inc	bx
	mov	ah,al
	and	al,7fh
	cmp	al,'G'
	je	compare_group
	cmp	al,'S'
	je	compare_size
	cmp	al,'D'
	je	compare_date
	mov	si,0
	mov	cx,11
	cmp	al,'N'
	je	compare_text
	mov	si,8
	mov	cx,3
compare_text:
	mov	di,si
	repe	cmpsb
	jmp	short key_result
compare_group:
	mov	al,es:[dir_attr]
	and	al,attr_directory
	mov	dl,ds:[dir_attr]
	and	dl,attr_directory
	cmp	al,dl
	jmp	short key_result
compare_size:
	mov	dx,ds:[dir_size_h]
	cmp	dx,es:[dir_size_h]
	jne	key_result
	mov	dx,ds:[dir_size_l]
	cmp	dx,es:[dir_size_l]
	jmp	short key_result
compare_date:
	mov	dx,ds:[dir_date]
	cmp	dx,es:[dir_date]
	jne	key_result
	mov	dx,ds:[dir_time]
	cmp	dx,es:[dir_time]
key_result:
	je	key_loop
 ; Preserve the comparison carry while testing the reverse bit.
	pushf
	test	ah,80h
	jnz	reversed
	popf
	ret
reversed:
	popf
	cmc
	ret
compare_ordinal:
	mov	dx,ds:[32]
	cmp	dx,es:[32]
	ret
compare_entries endp

; Shell sort by halving gaps. The ordinal tie-break preserves disk order.
dir_sort proc near
	mov	ax,records
next_gap:
	shr	ax,1
	jz	sort_done
	mov	gap,ax
	mov	outer_index,ax
next_outer:
	mov	ax,outer_index
inner_loop:
	cmp	ax,gap
	jb	outer_done
	push	ax
	call	record_segment
	mov	right_seg,ax
	pop	ax
	sub	ax,gap
	push	ax
	call	record_segment
	mov	left_seg,ax
	push	ds
	push	es
	mov	es,ax
	mov	ds,right_seg
	call	compare_entries
	jnc	pair_done
	xor	si,si
	mov	cx,17
swap_words:
	mov	ax,[si]
	xchg	ax,es:[si]
	mov	[si],ax
	add	si,2
	loop	swap_words
	pop	es
	pop	ds
	pop	ax
	jmp	inner_loop
pair_done:
	pop	es
	pop	ds
	pop	ax
outer_done:
	inc	outer_index
	mov	ax,outer_index
	cmp	ax,records
	jb	next_outer
	mov	ax,gap
	jmp	next_gap
sort_done:
	mov	dir_replay,1
	ret
dir_sort endp

; Carry set at the end of the sorted list.
dir_take proc near
	mov	ax,cursor
	cmp	ax,records
	jae	take_done
	inc	cursor
	call	record_segment
	push	ds
	mov	ds,ax
	xor	si,si
	mov	di,offset trangroup:dirbuf+8
	mov	cx,16
	rep	movsw
	pop	ds
	clc
	ret
take_done:
	stc
	ret
dir_take endp
TRANCODE ends
end
