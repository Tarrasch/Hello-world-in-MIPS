		#include <iregdef.h>
		.data
thing:	.asciiz "Hej Kalle!\n"	# \n means newline

		.text						# Start generating instructions
		.globl	main				# The label should be globally known
		.ent	main				# The label marks an entry point
main:
		li		v0, 4
		la		a0, thing
		syscall	
loop_here:
		j loop_here
	
		.end	main