# spimbot constants
VELOCITY      = 0xffff0010
ANGLE         = 0xffff0014
ANGLE_CONTROL = 0xffff0018
BOT_X         = 0xffff0020
BOT_Y         = 0xffff0024

OTHER_BOT_X = 0xffff00a0
OTHER_BOT_Y = 0xffff00a4

FRUIT_SMOOSHED_ACK = 0xffff0064
FRUIT_SMOOSHED_INT_MASK = 0x2000

FRUIT_SMASH = 0xffff0068
FRUIT_SCAN    = 0xffff005c

BONK_MASK     = 0x1000
BONK_ACK      = 0xffff0060

TIMER         = 0xffff001c
TIMER_MASK    = 0x8000
TIMER_ACK     = 0xffff006c

OUT_OF_ENERGY_ACK       = 0xffff00c4
OUT_OF_ENERGY_INT_MASK  = 0x4000

GET_ENERGY = 0xffff00c8

REQUEST_PUZZLE = 0xffff00d0
SUBMIT_SOLUTION = 0xffff00d4

REQUEST_PUZZLE_ACK = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800

REQUEST_WORD = 0xffff00dc

.data
.align 2
fruit_data : .space 260
count : .word 0

.text
main:
	la $t0, fruit_data
	sw $t0, FRUIT_SCAN
	# enable interrupts
	li	$t4, FRUIT_SMOOSHED_INT_MASK		# timer interrupt enable bit
	or	$t4, $t4, BONK_MASK	# bonk interrupt bit
	or	$t4, $t4, 1		# global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)

bottom:
	lw $t1, BOT_Y
	bge $t1, 294, find_fruit
	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	li $t2, 90
	sw $t2, ANGLE #angle 90
	li $t2, 10
	sw $t2, VELOCITY #velocity 10
	j bottom

find_fruit:
	la $t6, count # count address
	lw $t7, 0($t6) # count value
	li $t6, 5
	bge $t7, $t6, get_bonked

	li $t2, 10
	sw $t2, VELOCITY #velocity 10
	lw $t4, 0($t0)
	lw $t3, 8($t0) #the x coordinate of the fruit
	lw $t1, BOT_X
	beq $t3, $t1, wait
	bgt $t3, $t1, right
	blt $t3, $t1, left

get_bonked:
	li $t8, 1
	sw $t8, ANGLE_CONTROL #absolute angle
	li $t8, 90
	sw $t8, ANGLE #angle 90
	li $t8, 10
	sw $t8, VELOCITY #velocity 10
	
	la $t6, count # count address
	lw $t7, 0($t6) # count value
	beq $t7, $zero, find_fruit

	j get_bonked

right:

	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	sw $zero, ANGLE #angle 0 (turn right)
	lw $t1, BOT_X
	beq $t3, $t1, wait
	bgt $t3, $t1, main
	j right

left:

	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	li $t2, 180
	sw $t2, ANGLE #angle 180 (left)
	lw $t1, BOT_X
	beq $t3, $t1, wait
	blt $t3, $t1, main
	j left

wait:
	la $t0, fruit_data
	sw $t0, FRUIT_SCAN
	sw $zero, VELOCITY #velocity 0
	lw $t5, 0($t0) #id
	bne $t4, $t5, find_fruit
	j wait


.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for two registers
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable     

	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and	$a0, $k0, FRUIT_SMOOSHED_INT_MASK	# is there a smoosh interrupt?
	bne	$a0, 0, fruit_smooshed_interrupt

	and	$a0, $k0, BONK_MASK	# is there a bonk interrupt?                
	bne	$a0, 0, bonk_interrupt   

	# add dispatch for other interrupt types here.

	#li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done


fruit_smooshed_interrupt:

	la $t6, count # count address
	lw $t7, 0($t6) # count value
	addi $t7, $t7, 1 #increment it
	sw $t7, 0($t6) #store it back in 

	li $t8, 5
	blt $t7, $t8, no_smash

	#li $t8, 1
	#sw $t8, ANGLE_CONTROL #absolute angle
	#li $t8, 90
	#sw $t8, ANGLE #angle 90
	#li $t8, 10
	#sw $t8, VELOCITY #velocity 10

	li $t9, 1 #flag to say you should smash

	#li $t8, 10000

	#j	stall	# see if other interrupts are waiting

#stall:
	#ble $t8, 0, interrupt_dispatch
	#sub $t8, $t8, 1
	#j stall
	sw $a1, FRUIT_SMOOSHED_ACK

	j interrupt_dispatch

no_smash:
	sw $a1, FRUIT_SMOOSHED_ACK

	j interrupt_dispatch

bonk_interrupt:

	beq $t9, 1, smash #check to see if its smash time

	la $t6, count # count address
	sw $zero, 0($t6) # count value

	sw	$a1, BONK_ACK		# acknowledge interrupt
	#sw	$zero, VELOCITY		# 0

	j	interrupt_dispatch	# see if other interrupts are waiting

smash:

	la $t6, FRUIT_SMASH
	sw $zero, 0($t6) #smash 1
	sw $zero, 0($t6) #smash 1
	sw $zero, 0($t6) #smash 1
	sw $zero, 0($t6) #smash 1
	sw $zero, 0($t6) #smash 1

	li $t9, 0

	j bonk_interrupt

non_intrpt:				# was some non-interrupt
	#li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret