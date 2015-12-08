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

# Make sure space is aligned to 2^2 bits
.data:

.align 2 
fruit_data: .space 260

puzzle_grid: .space 8192

puzzle_word: .space 128

node_address: .word node_memory

node_memory: .space 4096

num_smooshed: .word 0

.globl num_rows
num_rows: .word 16
.globl num_cols
num_cols: .word 16

.text
main:
	# $t0 - for ANGLE and ANGLE_CONTROL
	# $t1 - for VELOCITY
	# $t2 - for BOT_X and BOT_Y
	# $t3 - for getting id of closest fruit
	# $t4 - x-coord of fruit 
	# $t5 - index of the fruit in the array
	# $t6 - temporary x-coord of the fruit in the array

	# $s0 - fruit_data 
	# $s1 - puzzle_grid
	# $s2 - puzzle_word
	# $s3 - node_address
	# $s4 - node_memory
	# $s5 - num_smooshed

	# Enable interrupts
	li 	$t0, BONK_MASK				# bonk interrupt bit
	or 	$t0, $t0, FRUIT_SMOOSHED_INT_MASK		# smoosh interrupt bit
	or	$t0, $t0, 1					# global interrupt enable
	mtc0 $t0, $12					# set interrupt mask (Status register)

	# Request a puzzle
	la $s1, puzzle_grid
	sw $s1, REQUEST_PUZZLE


move_bottom:
	lw $t0, BOT_Y
	bge $t0, 294, look_for_fruit
	
	# Orient SPIMbot
	li $t1, 90				# +y = 90
	sw $t1, ANGLE
	li $t1, 1 				# Absolute angle
	sw $t1, ANGLE_CONTROL

	# Set velocity
	li $t1, 10
	sw $t1, VELOCITY

	j move_bottom

look_for_fruit:
	# Populate fruit_data with the array of fruit information
	la $s0, fruit_data
	sw $s0, FRUIT_SCAN

	## Check if fruit array is empty
	# Get id of first fruit
	lw $t3, 0($s0)
	# Check if first fruit is NULL
	beq $t3, $zero, look_for_fruit

	# Get x coordinate of first fruit and SPIMbot
	lw $t4, 8($s0)	# x-coord of first fruit
	lw $t2, BOT_X 	# x-coord of bot
	# If x-coord of fruit > x-coord of SPIMbot, move right. Else, move left.
	bgt $t4, $t2, move_right
	blt $t4, $t2, move_left
wait_to_smoosh_fruit:				# If the same x-coord, wait for fruit to smoosh

	la $s0, fruit_data
	sw $s0, FRUIT_SCAN
	lw $t2, BOT_X
	lw $t4, 8($s0) #original id 
	#bne $t4, 0, wait_to_smoosh_fruit
	beq $t2, $t4, smash_fruit

	## WAIT TO SMOOSH THE FRUIT ##
	sw $zero, VELOCITY

	# Wait for fruit until it smashes
	la $s0, fruit_data
	sw $s0, FRUIT_SCAN

	# Get id of first fruit in the array
	lw $t9, 0($s0)
	# If the id = the id of the fruit we are smooshing, keep waiting
	beq $t3, $t9, wait_to_smoosh_fruit
	j look_for_fruit

smash_fruit:
	# Orient SPIMbot to face downwards
	li $t0, 90				# +y = 90
	sw $t0, ANGLE
	li $t0, 1 				# Absolute angle
	sw $t0, ANGLE_CONTROL
	# Move SPIMbot to the bottom of the screen
	li $t1, 10
	sw $t1, VELOCITY

	lw $t1, num_smooshed
	beq $t1, 0, look_for_fruit

	j smash_fruit

move_right: 				# Move right since x-coord of SPIMbot > x-coord of the fruit
	# Orient SPIMbot to the right
	li $t0, 0 				# +x = 0
	sw $t0, ANGLE
	li $t0, 1 				# Absolute angle
	sw $t0, ANGLE_CONTROL
	# Set SPIMbot velociy to +
	li $t1, 10
	sw $t1, VELOCITY

	j look_for_fruit

move_left:					# Move left while x-coord of SPIMbot < x-coord of the fruit
	# Orient SPIMbot to the left
	li $t0, 180				# -x = 180
	sw $t0, ANGLE
	li $t0, 1 				# Absolute angle
	sw $t0, ANGLE_CONTROL
	# Set SPIMbot velociy to +
	li $t1, 10
	sw $t1, VELOCITY

	j look_for_fruit


#############################################################
#################### Node methods ###########################
#============================================================

# Search neighbors method to solve the puzzle
.globl search_neighbors
search_neighbors:
	bne	$a1, 0, sn_main		# !(word == NULL)
	li	$v0, 0			# return NULL (data flow)
	jr	$ra			# return NULL (control flow)

sn_main:
	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

	move	$s0, $a0		# puzzle
	move	$s1, $a1		# word
	move	$s2, $a2		# row
	move	$s3, $a3		# col
	li		$s4, 0			# i

sn_loop:
	mul	$t0, $s4, 8		# i * 8
	lw	$t1, directions($t0)	# directions[i][0]
	add	$s5, $s2, $t1		# next_row
	lw	$t1, directions+4($t0)	# directions[i][1]
	add	$s6, $s3, $t1		# next_col

	ble	$s5, -1, sn_next	# !(next_row > -1)
	lw	$t0, num_rows
	bge	$s5, $t0, sn_next	# !(next_row < num_rows)
	ble	$s6, -1, sn_next	# !(next_col > -1)
	lw	$t0, num_cols
	bge	$s6, $t0, sn_next	# !(next_col < num_cols)

	mul	$t0, $s5, $t0		# next_row * num_cols
	add	$t0, $t0, $s6		# next_row * num_cols + next_col
	add	$s7, $s0, $t0		# &puzzle[next_row * num_cols + next_col]
	lb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col]
	lb	$t1, 0($s1)		# *word
	bne	$t0, $t1, sn_next	# !(puzzle[next_row * num_cols + next_col] == *word)

	lb	$t0, 1($s1)		# *(word + 1)
	bne	$t0, 0, sn_search	# !(*(word + 1) == '\0')
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	li	$a2, 0			# NULL
	jal	set_node		# $v0 will contain return value
	j	sn_return

sn_search:
	li	$t0, '*'
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = '*'
	move	$a0, $s0		# puzzle
	add	$a1, $s1, 1		# word + 1
	move	$a2, $s5		# next_row
	move	$a3, $s6		# next_col
	jal	search_neighbors
	lb	$t0, 0($s1)		# *word
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = *word
	beq	$v0, 0, sn_next		# !next_node
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	move	$a2, $v0		# next_node
	jal	set_node
	j	sn_return

sn_next:
	add	$s4, $s4, 1		# i++
	blt	$s4, 4, sn_loop		# i < 4
	
	li	$v0, 0			# return NULL (data flow)

sn_return:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	lw	$s7, 32($sp)
	add	$sp, $sp, 36
	jr	$ra


# Removes the passed in node
.globl remove_node
remove_node:
	move $t0, $a0 

first: 
	lw $t1, 0($t0) #get *curr
	beq $t1, 0, exitbai # if *curr == 0, break 

	lw $t2, 0($t1) # entry ->row
	lw $t3, 4($t1) #entry ->col

	bne $t2, $a1, exit #if entry->row == row
	bne $t3, $a2, exit #if entry->col == col

	lw $t6, 8($t1) # load entry->next into a temp
	sw $t6, 0($t0) # store entry->next into curr

	jr $ra #return

exit: 
	addi $t1, $t1, 8
	move $t0, $t1
	j first

exitbai:
	jr $ra


# Sets the node to a certain value
.globl set_node
set_node:
	
	sub $sp, $sp, 16
	sw $ra, 0($sp)
	sw $a0, 4($sp)
	sw $a1, 8($sp)
	sw $a2, 12($sp)

	jal allocate_new_node

	lw $a0, 4($sp)
	lw $a1, 8($sp)
	lw $a2, 12($sp)

	sw $a0, 0($v0)
	sw $a1, 4($v0)
	sw $a2, 8($v0)

	lw $ra, 0($sp)
	add $sp, $sp, 16
	jr	$ra


# Allocates "memory" for a new node using the space in node_memory.
# Arguments: none
# Returns: pointer to new node
.globl allocate_new_node
allocate_new_node:
	lw	$v0, node_address
	add	$t0, $v0, 12
	sw	$t0, node_address
	jr	$ra




# ===== INTERRUPTS ===== #
.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for a register

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at				# Save $at
.set at
	la	$k0, chunkIH
	sw	$t0, 0($k0)					# Get some free registers
	sw	$t1, 4($k0)					# by storing them to a global variable


	mfc0	$k0, $13				# Get Cause register
	srl	$t0, $k0, 2
	and	$t0, $t0, 0xf				# ExcCode field                

interrupt_dispatch:					# Interrupt:                          
	mfc0	$k0, $13				# Get Cause register, again
	beq	$k0, 0, done				# handled all outstanding interrupts     

	and	$t0, $k0, BONK_MASK						# is there a bonk interrupt?                
	bne	$t0, 0, bonk_interrupt

	and $t0, $k0, FRUIT_SMOOSHED_INT_MASK		# is there a smoosh interrupt?
	bne $t0, 0, smoosh_interrupt

	and $t0, $k0, REQUEST_PUZZLE_INT_MASK		# is there a request puzzle interrupt?
	bne $t0, 0, request_puzzle_interrupt

	j	done

smoosh_interrupt:
	# Increment num_smooshed
	lw $t0, num_smooshed			# $t0 = num_smooshed
	add $t0, $t0, 1					# $t0 += 1
	sw $t0, num_smooshed			# num_smooshed = $t0
	sw $t1, FRUIT_SMOOSHED_ACK			# acknowledge smoosh
	j interrupt_dispatch 			# Check if other interrupts are waiting

bonk_interrupt:
	sw	$zero, VELOCITY				# Stop the SPIMbot
keep_smashing:
	lw $t0, num_smooshed			# $t0 = num_smooshed
	beq $t0, $0, done_smashing		# if num_smooshed > 0
	sw $zero, FRUIT_SMASH			# Smash a fruit
	sub $t0, $t0, 1					# num_smooshed--
	sw $t0, num_smooshed
	j keep_smashing
done_smashing:
	# Acknowledge bonk interrupt after smashing fruits
	sw	$t1, BONK_ACK		# acknowledge bonk interrupt
	j	interrupt_dispatch	# see if other interrupts are waiting

request_puzzle_interrupt:
	la $s2, puzzle_word				# Load the address of the space we allocated for the word
	sw $s2, REQUEST_WORD			# 

	# REMEMBER TO SAVE REGSITERS AND RESTORE AFTER INTERRUPTS
	move $a0, $s2		# $a0 = puzzle
	move $a1, $s3		# $a1 = word
	move $a2, $zero		# change pls 
	move $a3, $zero		# same
	jal search_neighbors

	sw $v0, node_memory				# Store returned linked list into space we allocated
	sw $v0, SUBMIT_SOLUTION

	# Request a puzzle
	la $s1, puzzle_grid
	sw $s1, REQUEST_PUZZLE

	# Acknowledge request puzzle interrupt after smashing fruits
	sw	$t1, REQUEST_PUZZLE_ACK		# acknowledge bonk interrupt
	j	interrupt_dispatch	# see if other interrupts are waiting 

done:
	la	$k0, chunkIH
	lw	$t0, 0($k0)		# Restore saved registers
	lw	$t1, 4($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret