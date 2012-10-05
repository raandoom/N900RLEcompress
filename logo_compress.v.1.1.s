	.syntax unified
	.global main
	.code 32

main:
	push    {r0-r8,lr}
	ldr	r0, =info
	bl	printf
	mov     r0, 0x100
	bl      malloc
	push    {r0}            @@ [sp]-4 mem for stat
	mov     r1, r0
	ldr     r0, =rawbmp_fpath
	bl      stat
	cmp     r0, 0
	beq     file_ok
	ldr     r0, =errnofile
	bl      printf

err_ex:
	pop {r0}
	bl	free
	pop {r0-r8,pc}

file_ok:
	ldr     r0, [sp]
	ldr     r1, [r0,0x2c]	@@ stat + 0x2C = f_size
	cmp     r1, 0
	bne     filesize_ok
	ldr     r0, =nullsize
	bl      printf
	b	err_ex

filesize_ok:
	ldr     r0, =nullsize
	add     r0, 7
	bl      printf
	ldr     r0, [sp]
	ldr     r0, [r0,0x2c]	@@ stat + 0x2C = f_size
	bl      malloc
	push    {r0}		@@ [sp]-8 mem for read
	ldr     r0, =rawbmp_fpath
	ldr     r1, =r_mode
	bl      fopen
	cmp     r0, 0
	bne     fileopen_ok
	ldr     r0, =fopenerr
	bl      printf

err_ex_2:
	pop     {r0}
	bl      free
	b	err_ex

fileopen_ok:
	push {r0}		@@ [sp]-0xC ;save f_ptr for close
	mov     r3, r0		@@ f_ptr
	ldr     r2, [sp,8]	@@ get stat
	ldr     r2, [r2,0x2c]   @@ get f_size
	mov     r1, 1		@@ block_size
	ldr     r0, [sp,4]	@@ get mem for read
	bl      fread
	mov     r1, r0
	ldr     r0, =readed
	bl      printf
	pop {r0}		@@ [sp]-8 ;close file
	bl	fclose
	ldr	r1, [sp,4]
	ldr	r1, [r1,0x2c]	@@ get file size
	lsr	r0, r1, 1
	ldr	r3, j_count_repeat_groups
	add	r3, 1
	blx	r3
	add	r0, r1, r0
	lsr	r0, r0, 8
	lsl	r0, r0, 8
	add	r0, 0x10
	bl      malloc
	push	{r0}		@@ [sp]-0xC mem for write
	mov	r2, r0
	ldr	r1, [sp,4]
	ldr	r0, [sp,8]
	ldr	r0, [r0,0x2c]
	lsr	r0, r0, 1
	ldr	r3, j_compress
	add	r3, 1
	blx	r3
	ldr	r1, [sp]
	sub	r0, r1	@@ rle size
	push	{r0}
	ldr     r0, =nolo_logo_fpath
	ldr     r1, =w_mode
	bl      fopen
	cmp     r0, 0
	bne     filecreated_ok
	add sp, 4
	ldr     r0, =fcreateerr
	bl      printf
err_ex_3:
	pop {r0}
	bl	free
	b	err_ex_2

filecreated_ok:
	push {r0}
	ldr	r3, [sp]
	ldr	r2, [sp,4]
	mov	r1, 1
	ldr	r0, [sp,8]
	bl	fwrite
	ldr     r0, =created
	bl      printf
	pop {r0}
	bl	fclose
	add sp, 4
	b	err_ex_3

	.align 4

j_compress:
	.word _compress
j_count_repeat_groups:
	.word count_repeat_groups

	.align 1
@@__test: .asciz "value = %d\n"
info:
	.ascii "### Logo Compress Elf for N900 by RaANdOoM\n"
	.ascii "# ver.1.1 (added support for any image size)\n"
	.ascii "# Usage: rename RAW from your image to 'rawbmp.bin'\n"
	.ascii "# Put 'rawbmp.bin' near this elf and run elf\n"
	.ascii "# Compressed image will be in file 'logo.bin'\n"
	.asciz "###\n"
rawbmp_fpath:
	.asciz "./rawbmp.bin"
nolo_logo_fpath:
	.asciz "./logo.bin"
errnofile:
	.asciz "Error: There is no 'rawbmp.bin' file for compress!\n"
nullsize:
	.asciz "Error: Size of 'rawbmp.bin' is %d bytes\n"
r_mode:
	.asciz "r"
w_mode:
	.asciz "w"
fopenerr:
	.asciz "Error: 'fopen' return error value\n"
readed:
	.asciz "fread: %d bytes succesfully readed\n"
fcreateerr:
	.asciz "Error: can't create 'logo.bin'!\n"
created:
	.asciz "All ok! 'logo.bin' created\n"

	.align 2
	.code 16

@@ r0 = hword count = fsize/2
@@ r1 = raw mem (16bpp bmp raw) = 59904 bytes = 0xea00
@@ r2 = rle mem (for write rle) = fsize + (fsize/0x7f) +~> 0x10

@@=====================
_compress:
push {r0-r8,lr}
mov	r6, r0			@@ r6 = count halfs
mov	r7, r1			@@ r7 = read mem
mov	r8, r2			@@ r8 = write mem

_again_rle:
cmp	r6, 0			@@ if nothing to read
beq	_end_rle_write
cmp	r6, 1			@@ if there is last one halfword
beq	_last_half

ldrh	r0, [r7]		@@ get 1st half
ldrh	r1, [r7,2]		@@ get 2nd half
cmp	r0, r1
beq	_loc_count_repeat	@@ if 1st == 2nd

				@@ if 1st != 2nd
mov	r1, r7			@@ r1 = read mem
mov	r0, r6			@@ r0 = count all

bl	count_non_repeat	@@ out r0 = non repeat count

cmp	r0, 0x7f		@@ max group is 0x7f, check this
bhi	_loc_write_non_repeat_groups	@@ if there is more than 0x7f

				@@ if there is less than 0x7f
mov	r2, r8			@@ r2 = write mem
mov	r1, r7			@@ r1 = read mem

bl	write_non_repeat	@@ r0 = count ;save {r0-r8}

sub	r6, r0			@@ count all - count = how many halfs untill the end
lsl	r0, r0, 1		@@ readed bytes
add	r7, r0			@@ add bytes to read mem
add	r8, 1			@@ add count byte to write mem
add	r8, r0		@@ add bytes to write mem
b	_again_rle

_loc_write_non_repeat_groups:
push {r0}			@@ save count
mov	r2, r8			@@ r2 = write mem
mov	r1, r7			@@ r1 = read mem

bl	write_non_repeat_groups	@@ r0 = count ;out r0 = count groups

add	r8, r0			@@ add	group count to write mem
pop {r0}			@@ get count
sub	r6, r0			@@ count all - count = how many halfs untill the end
lsl	r0, r0, 1		@@ readed bytes
add	r7, r0			@@ add bytes to read mem
add	r8, r0			@@ add bytes to write mem
b	_again_rle

_loc_count_repeat:
mov	r1, r7			@@ r1 = read mem
mov	r0, r6			@@ r0 = count all

bl	count_repeat		@@ out r0 = repeat count

cmp	r0, 0x7f		@@ max group is 0x7f, check this
bhi	_loc_write_repeat_groups	@@ if there is more than 0x7f

				@@ if there is less than 0x7f
add	r3, r0, 0x80		@@ add 0x80 to count, because repeated byte
strb	r3, [r8]		@@ write repeat byte

ldrh	r3, [r7]	@@ get repeat half
sub sp, 4
strh	r3, [sp]
ldrb	r3, [sp]
strb	r3, [r8,2]		@@ write repeated half
ldrb	r3, [sp,1]
strb	r3, [r8,1]
add sp, 4
add	r8, 3			@@ add 3 byte, because ([1Byte][2Byte])
sub	r6, r0			@@ count all - count = how many halfs untill the end
lsl	r0, r0, 1		@@ readed bytes
add	r7, r0			@@ add bytes to read mem
b	_again_rle

_loc_write_repeat_groups:
push {r0}			@@ save count

bl	count_repeat_groups	@@ r0 = count ;out r0 = count groups

mov	r3, r0
mov	r2, 0x7f
add	r4, r2, 0x80		@@ group lenght
ldrh	r1, [r7]		@@ get repeat half
sub sp, 4
strh	r1, [sp]

_again_write_r_groups:
strb	r4, [r8]
ldrb	r1, [sp]
strb	r1, [r8,2]
ldrb	r1, [sp,1]
strb	r1, [r8,1]
add	r8, 3
sub	r3, 1
cmp	r3, 0
beq	_stop_write_r_groups
b	_again_write_r_groups

_stop_write_r_groups:
ldr	r3, [sp,4]		@@ get repeat count
mul	r2, r0
sub	r3, r3, r2
cmp	r3, 0
beq	_exit_write_r_groups

add	r3, r3, 0x80
strb	r3, [r8]
ldrb	r1, [sp]
strb	r1, [r8,2]
ldrb	r1, [sp,1]
strb	r1, [r8,1]
add	r8, 3

_exit_write_r_groups:
add sp, 4
pop {r0}
sub	r6, r0
lsl	r0, r0, 1		@@ readed bytes
add	r7, r0

b	_again_rle

_last_half:			@@ if there is last one halfword
mov	r0, 1			@@ count = 1
strb	r0, [r8]		@@ write count like non repeat
ldrh	r1, [r7]		@@ get last half
strh	r1, [r8,1]		@@ write last half
add	r8, 3

_end_rle_write:			@@ if nothing to read
mov	r0, 0
strb	r0, [r8]
add	r8, 1
str	r8, [sp]
pop {r0-r8,pc}
@@=====================

count_non_repeat:	@@ if 1st half != 2nd half
			@@ in r0 = count all
			@@ in r1 = read mem
			@@ out r0 = non repeat count
push {r0-r8,lr}
mov	r5, r1		@@ r5 = read mem
mov	r7, 1		@@ r7 = count = 1
mov	r8, r0		@@ r8 = count all

cmp	r8, 2		@@ check if there is last 2 halfs
beq	_add_last_non_repeat
b	_start_count_non_repeat

_check_next_non_repeat:
add	r5, 2		@@ add 2 bytes to read mem
add	r7, 1		@@ add count
sub	r3, r8, r7	@@ check for the end of read mem
cmp	r3, 1		@@ if the last one left
beq	_add_last_non_repeat

_start_count_non_repeat:
ldrh	r1, [r5,2]	@@ get 2nd half
ldrh	r2, [r5,4]	@@ get 3rd half
cmp	r1, r2		@@ check for start of repeat group
bne	_check_next_non_repeat
b	_end_counts_non_repeat

_add_last_non_repeat:
add	r7, 1

_end_counts_non_repeat:
mov	r0, r7
add sp, 4
pop {r1-r8,pc}
@@=====================

write_non_repeat_groups:	@@ r2 = write mem
				@@ r1 = read mem
				@@ r0 = count ;out r0 = count groups
push {r0-r8,lr}
mov	r7, 1			@@ r7 = groups
mov	r3, 0x7f		@@ r3 = group lenght

_again_count_nonr_groups:
lsl	r3, r3, 1
cmp	r3, r0
bhi	_stop_count_nonr_groups	@@ r7 = group; + 1 not full group
add	r7, 1
cmp	r3, r0
beq	_stop_count_nonr_groups
b	_again_count_nonr_groups

_stop_count_nonr_groups:	@@ r7 = group
mov	r8, r7
ldr	r2, [sp,8]
ldr	r1, [sp,4]
mov	r0, 0x7f

_again_write_nonr_groups:
bl	write_non_repeat
lsl	r3, r0, 1
add	r1, r3
add	r2, r3, 1
sub	r8, 1
cmp	r8, 0
beq	_stop_write_nonr_groups
b	_again_write_nonr_groups

_stop_write_nonr_groups:
mul	r3, r7	
ldr	r0, [sp]
sub	r0, r3
cmp	r0, 0
beq	_exit_write_nonr_groups

bl	write_non_repeat
add	r7, 1

_exit_write_nonr_groups:
mov	r0, r7
add sp, 4
pop {r1-r8,pc}
@@=====================
write_non_repeat:	@@ if there is less than 0x7f
			@@ in r0 = count non repeat
			@@ in r1 = read mem
			@@ in r2 = write mem
push {r0-r8,lr}
strb	r0, [r2]	@@ write count byte
add	r2, 1		@@ add write mem

_again_write_non_repeat:
ldrh	r3, [r1]	@@ get non repeat half
sub	sp, 4
strh	r3, [sp]
ldrb	r3, [sp]
strb	r3, [r2,1]	@@ write non repeat byte
ldrb	r3, [sp,1]
strb	r3, [r2]
add	sp, 4
add	r1, 2		@@ add write mem
add	r2, 2		@@ add read mem
sub	r0, 1		@@ non repeat halfs left
cmp	r0, 0		@@ is this last half?
beq	_ex_write_non_repeat
b	_again_write_non_repeat

_ex_write_non_repeat:
pop {r0-r8,pc}

@@=====================
count_repeat:		@@ if 1st half = 2nd half
			@@ in r0 = count all
			@@ in r1 = read mem
			@@ out r0 = count of repeat
push {r0-r8,lr}
mov	r5, r1		@@ r5 = read mem
mov	r7, 1		@@ r7 = count = 1
mov	r8, r0		@@ r8 = count all

cmp	r8, 2		@@ check if there is last 2 halfs
beq	_add_last_repeat
b	_start_count_repeat

_loc_add_repeat:
add	r5, 2
add	r7, 1
sub	r3, r8, r7
cmp	r3, 1
beq	_add_last_repeat

_start_count_repeat:
ldrh	r1, [r5]
ldrh	r2, [r5,2]
cmp	r1, r2
beq	_loc_add_repeat
b	_end_count_repeat

_add_last_repeat:
add	r7, 1

_end_count_repeat:
mov	r0, r7
add sp, 4
pop {r1-r8,pc}
@@=====================
count_repeat_groups:		@@ r1 = read mem
				@@ r0 = count ;out r0 = count groups
push {r0-r8,lr}
mov	r7, 1			@@ r7 = groups
mov	r3, 0x7f
mov	r4, r3

_again_count_r_groups:
add	r3, r4
cmp	r3, r0
bhi	_stop_count_r_groups	@@ r7 = group; + 1 not full group
add	r7, 1
cmp	r3, r0
beq	_stop_count_r_groups
b	_again_count_r_groups

_stop_count_r_groups:		@@ r7 = group
mov	r0, r7
add sp, 4
pop {r1-r8,pc}
@@=====================

