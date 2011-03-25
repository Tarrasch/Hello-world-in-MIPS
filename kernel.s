# lab1_kernel.s

#

# En kernel för:	Laboration i Datorsystemteknik

#			Gränssnittet hårdvara/mjukvara

#			Extrauppgift med IO

# Av Thomas Lundqvist (2001-03-14)

#

# All names/labels begin with __ in order to not conflict with

# user program names/labels.



#include <iregdef.h>

#include <idtcpu.h>

#include <excepthdr.h>



#define PIO_SETUP2 0xffffea2a



		.data

		

		# Format string for the the interrupt routine



Format:	.asciiz	"Cause = 0x%x, EPC = 0x%x, Interrupt I/O = 0x%x\n"





###########################################################################

# Standard startup code.  Invoke the routine main with no arguments.

 

		.text

		.globl	start				# The label should be globally known

		.ent	start				# The label marks an entry point

start:

		jal		__ioinit			# Initialize I/O

		

		lw		a0, 0(sp)			# argc

		addiu	a1, sp, 4			# argv

		addiu	a2, a1, 4			# envp

		sll		v0, a0, 2

		addu	a2, a2, v0

				

		jal   main

		

		li    v0, 10

		syscall						# syscall 10 (exit)

		

		.end start					# Marks the end of the program



###########################################################################

# Initialize interrupts and memory mapped I/O

 

__ioinit:

		lh		a0, PIO_SETUP2		# Enable button port interrupts

		andi	a0, 0xbfff

		sh		a0, PIO_SETUP2

		lui		t0, 0xbfa0			# Place interrupt I/O port adress in t0

		sb		zero,0x0(t0)		# Acknowledge interrupt, (resets latch)

		la		t0, intstub			# These instructions copy the stub

		la		t1, 0x80000080		# routine to address 0x80000080

		lw		t2, 0(t0)			# Read the first instruction in stub

		lw		t3, 4(t0)			# Read the second instruction

		sw		t2, 0(t1)			# Store the first instruction 

		sw		t3, 4(t1)			# Store the second instruction

		

		mfc0	v0, C0_SR 			# Retrieve the status register

		li		v1, ~SR_BEV			# Set the BEV bit of the status

		and		v0, v0, v1			# register to 0 (the first exception vetor)

		ori		v0, v0, 1			# Enable user defined interrupts

		ori		v0, v0, EXT_INT3	# Enable interrupt 3 (K1, K2, timer)

		mtc0	v0, C0_SR			# Update the status register



		jr		ra

		

###########################################################################

# The only purpose of the stub routine below is to call

# the real interrupt routine. It is used because it is 

# of fixed size and easy to copy to the interrupt start

# address location.



		.ent	intstub

		.set	noreorder

intstub:

		j		__trap_handler_start

		nop

		

		.set	reorder

		.end	intstub



###########################################################################

# Trap handler begins here



		.data						# Should be .kdata

__m1_:	.asciiz "  Exception "

__m2_:	.asciiz " occurred and ignored\n"

__e0_:	.asciiz "  [Hardware Interrupt] "

__e1_:	.asciiz	""

__e2_:	.asciiz	""

__e3_:	.asciiz	""

__e4_:	.asciiz	"  [Unaligned address in inst/data fetch] "

__e5_:	.asciiz	"  [Unaligned address in store] "

__e6_:	.asciiz	"  [Bad address in text read] "

__e7_:	.asciiz	"  [Bad address in data/stack read] "

__e8_:	.asciiz	"  [Syscall] "

__e9_:	.asciiz	"  [Breakpoint] "

__e10_:	.asciiz	"  [Reserved instruction] "

__e11_:	.asciiz	""

__e12_:	.asciiz	"  [Arithmetic overflow] "

__e13_:	.asciiz	"  [Inexact floating point result] "

__e14_:	.asciiz	"  [Invalid floating point result] "

__e15_:	.asciiz	"  [Divide by 0] "

__e16_:	.asciiz	"  [Floating point overflow] "

__e17_:	.asciiz	"  [Floating point underflow] "

__excp:	.word	__e0_,__e1_,__e2_,__e3_,__e4_,__e5_,__e6_,__e7_,__e8_,__e9_

		.word	__e10_,__e11_,__e12_,__e13_,__e14_,__e15_,__e16_,__e17_



__s_at:	.word	0

__s_v0:	.word	0

__s_a0:	.word	0

__s_a1:	.word	0

__s_a2:	.word	0

__s_a3:	.word	0

__s_v1:	.word	0

__s_t0:	.word	0

__s_t1:	.word	0

__s_s0:	.word	0

__s_ra:	.word	0

 

		.text						# Should be .ktext 0x80000080

		.globl	__trap_handler_start

		.ent	__trap_handler_start



__trap_handler_start:

		# Because we are running in the kernel, we can use k0/k1 without

		# saving their old values.

		.set	noat				# Permit direct use of at register

		la		k0, __s_at			# Save at, the assembler temporary register

		sw		AT, 0(k0)			# To be safe: go via k0	

		.set	at

		sw		v0, __s_v0			# Not re-entrent and we cant trust sp

		sw		a0, __s_a0			# Save all modified regs

		sw		a1, __s_a1

		sw		a2, __s_a2

		sw		a3, __s_a3

		sw		v1, __s_v1

		sw		t0, __s_t0

		sw		t1, __s_t1

		sw		s0, __s_s0

		sw		ra, __s_ra		

		

		mfc0	k0, C0_CAUSE		# Retrieve the cause register 

		mfc0	k1, C0_EPC			# Retrieve the EPC

		lui		s0, 0xbfa0			# Place interrupt I/O port adress in s0

		lbu     s0, 0x0(s0)			# Load s0 with the contents of the adress

		

		srl		k0, k0, 2

		andi	k0, k0, 0x1f		# Mask out exception code

		

		beq		k0, 0, __hardware	# hardware interrupt ?

		addi	k1, k1, 4			# software exception -> add 4 to return address

		b		__software

		

		.end	__trap_handler_start

		

		# Default action if exception not handled in

		# __software is to print out some information



__not_handled:

		la		a1, __m1_

		la		a0, __printf_string_string

		jal     printf				# Call printf to print string in a0

		move	a1, k0				# exception code

		la		a0, __printf_int_string

		jal     printf				# Call printf to print string in a0

		sll		a1, k0, 2			# Build index into __excp table

		lw		a1, __excp(a1)

		la		a0, __printf_string_string	

		jal     printf				# Call puts to print string in a0

		

		# Bad PC (exception code 6: bad address in text read) requires special checks

		bne		k0, 6, __ok_pc

		mfc0	a0, $14				# EPC

		and		a0, a0, 0x3			# Is EPC word-aligned?

		beq		a0, 0, __ok_pc

		jal		promexit			# Stop simulator on really bad PC (unaligned)



__ok_pc:

		la		a1, __m2_

		la		a0, __printf_string_string

		jal     printf	



###########################################################################

# Return from trap handler

 

__ret:	b		__hardware			# First - give hardware devices a chance



__really_ret:

		lui		s0, 0xbfa0			# Place interrupt I/O port adress in s0		

		sb		zero,0x0(s0)		# Acknowledge interrupt, (resets latch)



		lw		v0, __s_v0			# restore saved registers

		lw		a0, __s_a0

		lw		a1, __s_a1

		lw		a2, __s_a2

		lw		a3, __s_a3

		lw		v1, __s_v1

		lw		t0, __s_t0

		lw		t1, __s_t1

		lw		s0, __s_s0

		lw		ra, __s_ra

		.set	noat

		lw		AT, __s_at			# Restore at

		.set	at

		rfe							# Return from exception handler

		jr		k1					# Return to EPC or EPC+4



###########################################################################

# Hardware interrupts

#

# Special care must be taken in the hardware interrupt handlers.

# When executing in trap handler code, external interrupts are

# disabled. All interrupts that occur during this time is thereby lost.

# The solution is to poll all hardware devices iteratively until all

# interrupting devices have been served. We should not trust the

# cause register since this register shows us only the first reason

# why we entered the trap handler.



__hardware:	

		# Catch K1 key pressed interrupt

		lui		t0, 0xbfa0			# Place interrupt I/O port adress in t0

		lbu     t0, 0x0(t0)			# Load t0 with the contents of the adress

		

		andi	t0, t0, 32			# Mask out escape occured bit

		bnez	t0, __K1_handler



__hardware_K2:		

		# Catch K2 key pressed interrupt

		lui		t0, 0xbfa0			# Place interrupt I/O port adress in t0

		lbu     t0, 0x0(t0)			# Load t0 with the contents of the adress

		

		andi	t0, t0, 16			# Mask out escape occured bit

		bnez	t0, __K2_handler

		

__hardware_timer:

		# Catch external timer interrupt

		lui		t0, 0xbfa0			# Place interrupt I/O port adress in t0

		lbu     t0, 0x0(t0)			# Load t0 with the contents of the adress

		

		andi	t0, t0, 64			# Mask out escape occured bit

		bnez	t0, __external_timer_handler

		

		b		__really_ret



###########################################################################

# K1 key interrupt handler



		.data						# Should be .kdata

__K1_:	.asciiz	"Hardware interrupt: K1 key pressed!\n"

		.text						# Should be .ktext



__K1_handler:

		la		a0, __K1_

		jal		printf

		b		__hardware_K2



###########################################################################

# K2 key interrupt handler



		.data						# Should be .kdata

__K2_:	.asciiz	"Hardware interrupt: K2 key pressed!\n"

		.text						# Should be .ktext



__K2_handler:

		la		a0, __K2_

		jal		printf

		b		__hardware_timer

		

###########################################################################

# External timer interrupt handler



		.data						# Should be .kdata

__external_timer_:

		.asciiz	"Hardware interrupt: External timer!\n"

		.text						# Should be .ktext



__external_timer_handler:

		la		a0, __external_timer_

		jal		printf

		b		__really_ret

		

###########################################################################

# Software interrupts/exceptions



__software:

		# Check if we should execute a syscall (exception 8)

		beq		k0, 8, __syscall

		

		b		__not_handled



###########################################################################

# Handle syscall number 1-11 by forwarding the call to the simulator

# (using the sim instruction). The sim instruction takes the same

# parameters as syscall and delivers the same results. Therefore, copy

# the saved values of v0 and a0, and put the results back in the saved

# value of v0. This values will be restored to register v0 before the

# trap handler returns.



__syscall:

		beq		v0, 1, __print_int		#$a0 = integer

		#beq	v0, 2, __print_float 	#$f12 = float

		#beq	v0, 3, __print_double 	#$f12 = double

		beq		v0, 4, __print_string	#$a0 = string

		beq		v0, 5, __read_int 		#integer (in $v0)

		#beq	v0, 6, __read_float 	#float (in $f0)

		#beq	v0, 7, __read_double 	#double (in $f0)

		beq		v0, 8, __read_string 	#$a0 = buffer, $a1 = length

		#beq	v0, 9, __sbrk 			#$a0 = amount address (in $v0)

		beq		v0, 10, __exit

		beq		v0, 11, __print_char	#$a0 = char

		beq		v0, 12, __read_char		#char (in $a0)

		#beq	v0, 13, __open 			#$a0 = filename (string), $a1 = flags, $a2 = mode file descriptor (in $a0)

		#beq	v0, 14, __read 			#$a0 = file descriptor, $a1 = buffer, $a2 = length num chars read (in $a0)

		#beq	v0, 15, __write 		#$a0 = file descriptor, $a1 = buffer, $a2 = length num chars written (in $a0)

		#beq	v0, 16, __close 		#$a0 = file descriptor

		#beq	v0, 17, __exit2

		

		b		__not_handled



###########################################################################

# print_int (syscall 1): Outputs an integer 

#

# Args: a0 = the integer



		.data						# Should be .kdata

__printf_int_string:	.asciiz	"%d"

		.text						# Should be .ktext



__print_int:

		move	a1, a0

		la		a0, __printf_int_string



		jal     printf				# Call printf to print string in a0

		nop



		b		__ret



###########################################################################

# print_string (syscall 4): Outputs a string 

#

# Args: a0 = the string



		.data						# Should be .kdata

__printf_string_string:	.asciiz	"%s"

		.text						# Should be .ktext



__print_string:

		move	a1, a0

		la		a0, __printf_string_string

		

		jal     printf				# Call puts to print string in a0

		nop



		b		__ret



###########################################################################

# read_int (syscall 5): Reads an integer 

#

# Returns: v0 = the integer



__read_int:

		li		t0, 0

__read_int_loop:

		jal		getchar

		beq		v0, '\n', __end_read_int

		blt		v0, '0', __read_int_loop

		bgt		v0, '9', __read_int_loop

		move	a0, v0

		li		t1, 10

		mul		t0, t0, t1

		addi	v0, v0, -'0'

		add		t0, t0, v0

		jal		putchar

		b		__read_int_loop

		

__end_read_int:

		li		a0, '\n'

		jal		putchar

		sw		t0, __s_v0

		b		__ret





###########################################################################

# read_string (syscall 8): Reads a string 

#

# Args: $a0 = buffer

#		$a1 = length



__read_string:

		move	t0, a0

		blt		a1, 1, __end_read_string

__read_string_loop:

		beq		a1, 1, __null_terminate

		

		jal		getchar

		move	a0, v0

		jal		putchar

		sb		a0, 0(t0)

		addi	t0, t0, 1

		addi	a1, a1, -1

		

		beq		a0, '\n', __null_terminate

		

		b		__read_string_loop

		

__null_terminate:

		li		v0, '\0'

		sw		v0, 0(t0)



__end_read_string:

		

		b		__ret

		

###########################################################################

# exit (syscall 10): exits 

#



__exit:

		jal		promexit

		

###########################################################################

# __print_char (syscall 11): Outputs a character 

#

# Args: a0 = the character



__print_char:



		jal     putchar

		nop



		b		__ret

		

###########################################################################

# __read_char (syscall 12): Reads a character 

#

# Returns: a0 = the character



__read_char:



		jal     getchar

		nop

		

		move	a0, v0

		sw		a0, __s_a0



		b		__ret



# End of trap handler

###########################################################################



# This file should end with .text so that

# when user loads user program, .text is the default:

		.text