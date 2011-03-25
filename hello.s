		#include <iregdef.h>
		.data
thing:	.asciiz "I can't stop!\n"	# \n means newline

		.text						# Start generating instructions
		.globl	main				# The label should be globally known
		.ent	main				# The label marks an entry point
main:
		li		v0, 4
		la		a0, thing
		syscall	

		b main

		.end	main