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

NODE_SIZE = 12

.data
intro_str4: .asciiz "Find MEEEE\n"
.align 2
fruit_data: .space 260 # fruit_data = malloc(260);
count: .word 0 #count = 0
SMASH_TOTAL: .word 1 #SMASH_TOTAL = 1
puzzle_grid: .space 8192
puzzle_word: .space 128
node_memory: .space 4096
puzzle_received_flag: .word 0 #puzzle_received_flag = 0
new_node_address: .word node_memory

.globl num_rows
num_rows: .space 4
.globl num_cols
num_cols: .space 4

.globl directions
directions:
	.word -1  0
	.word  0  1
	.word  1  0
	.word  0 -1

#all the text for the code
.text

#ALL THE FRUIT SMASH CODE

############################################################
main:
	#Enable the interrupts
	la $t0, fruit_data
	sw $t0, FRUIT_SCAN

	la $t0, puzzle_grid
	sw $t0, REQUEST_PUZZLE

start:

	la $t4, puzzle_received_flag
	lw $t4, 0($t4)

	beq $t4, 1, find_row_col_of_first_word

	la $t4, puzzle_received_flag
	sw $zero, 0($t4) #puzzle hasn't been received yet

	# enable interrupts
	li	$t4, FRUIT_SMOOSHED_INT_MASK #timer interrupt enable bit
	or	$t4, $t4, BONK_MASK	 			#bonk interrupt bit
	or $t4, $t4, REQUEST_PUZZLE_INT_MASK #request_puzzle interrupt bit
	or $t4, $t4, OUT_OF_ENERGY_INT_MASK #out_of_energy bit
	or	$t4, $t4, 1		 		    #global interrupt enable
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

find_fruit:
	la $t6, count # count address
	lw $t7, 0($t6) # count value
	la $t6, SMASH_TOTAL
	lw $t6, 0($t6)
	bge $t7, $t6, get_bonked

	li $t2, 10
	sw $t2, VELOCITY #velocity 10
	lw $t4, 0($t0)
	lw $t3, 8($t0) #the x coordinate of the fruit
	lw $t1, BOT_X
	lw $t8, BOT_Y
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
	bgt $t3, $t1, start

	#PUZZLE CODE
	#la $a0, puzzle_grid
	#lw $a0, 0($a0)
	#la $a1, puzzle_word
	#lw $a1, 0($a1)
	#j find_row_col_of_first_word

	#jal search_neighbors

left:

	li $t2, 1
	sw $t2, ANGLE_CONTROL #absolute angle
	li $t2, 180
	sw $t2, ANGLE #angle 180 (left)
	lw $t1, BOT_X
	beq $t3, $t1, wait
	blt $t3, $t1, start

	#la $a0, puzzle_grid
	#lw $a0, 0($a0)
	#la $a1, puzzle_word
	#lw $a1, 0($a1)
	#j find_row_col_of_first_word

#Once the X-coordinates of the Bot matches the X-coordinate of the fruit
#It waits until the fruit falls down at the Bot

wait:
	
	#PUZZLE STUFF

	

	#la $s0, puzzle_grid
	#sw $s0, REQUEST_PUZZLE

	#FRUIT STUFF
	la $t0, fruit_data
	sw $t0, FRUIT_SCAN
	sw $zero, VELOCITY #velocity 0
	lw $t5, 0($t0) #id
	bne $t4, $t5, find_fruit
	
	j wait



############################################################

#ALL THE PUZZLE CODE

############################################################
#All the code for allocate_new_node
#.globl allocate_new_node
allocate_new_node:
	lw	$v0, new_node_address
	add	$t0, $v0, NODE_SIZE
	sw	$t0, new_node_address
	jr	$ra

#.globl set_node
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


	# Your code goes here :)
	sw $a0, 0($v0)
	sw $a1, 4($v0)
	sw $a2, 8($v0)

	lw $ra, 0($sp)
	add $sp, $sp, 16
	jr	$ra

#.globl remove_node #remove all nodes
remove_node:
	move $t8, $a0
	loop1:
		lw $t0, 0($t8) # entry = *head
		beq $t0, $0, ret

		lw $t1, 0($t0) #addr of row

		lw $t2, 4($t0) #addr of col

		bne $t1, $a1, skip
		bne $t2, $a2, skip

		lw $t3, 8($t0) #$t3: entry->next
		sw $t3, 0($t8) #*curr = entry->next
		j ret

	skip: 
		add $t0, $t0, 8
		move $t8, $t0

		j loop1

	ret:
		jr	$ra

print_things:
	la	$a0, intro_str4
	jal	print_string

search_neighbors:
	# Your code goes here :)
	sub $sp, $sp, 36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp) 
	sw $s2, 12($sp) 
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)

	beq $a1, $0, cs_exit #if word == NULL

	li $s0, 0 #i
	move $s1, $a0 #puzzle
	move $s2, $a2 #row
	move $s3, $a3 #col
	move $s4, $a1 # * word
	
	lw $t1, num_rows
	lw $t2, num_cols

	la $t3, directions #directions 2d array
	
	li $t4, 4 #4
	cs_loop:
		bge $s0, $t4, cs_exit

		mul $t5, $s0, 8 #8i
		add $t5, $t3, $t5 #address of directions
		lw $s5, 0($t5) #incomplete next_row
		lw $s6, 4($t5) #incomplete next_col

		add $s5, $s5, $s2 #complete next_row
		add $s6, $s6, $s3 #complete next_col
		
		li $t6, -1
		ble $s5, $t6, cs_loop_increment #next_row <= 1
		bge $s5, $t1, cs_loop_increment #next_row >= num_rows
		ble $s6, $t6, cs_loop_increment #next_col <= 1
		bge $s6, $t2, cs_loop_increment #next_col >= num_cols

		#PASSES ALL 4 CONDITIONS
		mul $t7, $s5, $t2 #next_row * num_cols
		add $t7, $t7, $s6 #next_rows * num_cols + next_col
		add $t7, $t7, $s1 #address of puzzle[next_rows * num_cols + next_col]
		lb $t8, 0($t7) #puzzle[next_rows * num_cols + next_col]

		lb $t0, 0($s4) # dereference word once
		bne $t8, $t0, cs_loop_increment #if puzzle[next_rows * num_cols + next_col] != *word increment

		add $t7, $s4, 1 #word + 1
		lb $t8, 0($t7) #word + 1
		beq $t8, $zero, cs_set_node

		mul $t7, $s5, $t2 #next_row * num_cols
		add $t7, $t7, $s6 #next_rows * num_cols + next_col
		add $t7, $t7, $s1 #address of puzzle[next_rows * num_cols + next_col]
		#lb $t8, 0($t7) #puzzle[next_rows * num_cols + next_col]
		li $t6, '*'
		sb $t6, 0($t7)#load into puzzle[next_rows * num_cols + next_col]

		add $t7, $s4, 1 #word + 1

		move $a0, $s1 #puzzle for search_neighbors
		move $a1, $t7 #word+1 for search_neighbors
		move $a2, $s5 #next_row for search_neighbors
		move $a3, $s6 #next_col for search_neighbors
		jal search_neighbors
		move $s7, $v0 #next_node

		lw $t1, num_rows
		lw $t2, num_cols
		la $t3, directions #directions 2d array
		li $t4, 4 #4

		mul $t7, $s5, $t2 #next_row * num_cols
		add $t7, $t7, $s6 #next_rows * num_cols + next_col
		add $t7, $t7, $s1 #address of puzzle[next_rows * num_cols + next_col]
		lb $t8, 0($s4) #* word
		sb $t8, 0($t7) # * word into puzzle[next_rows * num_cols + next_col]

		bne $s7, $zero, cs_set_node_last #if next_node != NULL

		j cs_loop_increment #increment and don't return

	cs_loop_increment:
		add $s0, $s0, 1
		j cs_loop

	cs_set_node:
		
		move $a0, $s5
		move $a1, $s6
		move $a2, $0
		jal set_node

		lw $t1, num_rows
		lw $t2, num_cols
		la $t3, directions #directions 2d array
		li $t4, 4 #4

		lw $ra, 0($sp)
		lw $s0, 4($sp) 
		lw $s1, 8($sp) 
		lw $s2, 12($sp)
		lw $s3, 16($sp) 
		lw $s4, 20($sp) 
		lw $s5, 24($sp)
		lw $s6, 28($sp)
		lw $s7, 32($sp) 
		add $sp, $sp, 36
		jr $ra

	cs_set_node_last:
		move $a0, $s5
		move $a1, $s6
		move $a2, $s7
		jal set_node

		lw $t1, num_rows
		lw $t2, num_cols
		la $t3, directions #directions 2d array
		li $t4, 4 #4

		lw $ra, 0($sp)
		lw $s0, 4($sp) 
		lw $s1, 8($sp)
		lw $s2, 12($sp)
		lw $s3, 16($sp) 
		lw $s4, 20($sp) 
		lw $s5, 24($sp)
		lw $s6, 28($sp)
		lw $s7, 32($sp)    
		add $sp, $sp, 36
		jr $ra

	cs_exit:
		move $v0, $0

		lw $t1, num_rows
		lw $t2, num_cols
		la $t3, directions #directions 2d array
		li $t4, 4 #4

		lw $ra, 0($sp)
		lw $s0, 4($sp) 
		lw $s1, 8($sp) 
		lw $s2, 12($sp) 
		lw $s3, 16($sp) 
		lw $s4, 20($sp) 
		lw $s5, 24($sp)
		lw $s6, 28($sp)
		lw $s7, 32($sp)    
		add $sp, $sp, 36
		jr $ra

#.globl find_row_col_of_first_word
find_row_col_of_first_word:
	#la $a0, puzzle_grid #pointer to puzzle_grid
	#sw $a0, REQUEST_PUZZLE
	la $a0, puzzle_grid
	la $a1, puzzle_word
	li $a2, 0 #row
	li $a3, 0 #col

	sub $sp, $sp, 32
	sw $ra, 0($sp)
	sw $s0, 4($sp) #offset
	sw $s1, 8($sp) #puzzle_grid[i][j]
	sw $s2, 12($sp) #puzzle_word[0]
	sw $s3, 16($sp) #num_rows
	sw $s4, 20($sp) #num_cols
	sw $s5, 24($sp) #temp rows/cols
	sw $s6, 28($sp)

	lb $s2, 0($a1) #puzzle_word[0]

	la $s3, num_rows
	lw $s5, 0($a0) #number of rows
	sw $s5, 0($s3) #store into num_rows
	move $s3, $s5 #load into s3

	la $s4, num_cols
	lw $s5, 4($a0) #number of columns
	sw $s5, 0($s4) #store into num_columns
	move $s4, $s5 #load into s3

	add $a0, $a0, 8

	row_iterator:
		bge $a2, $s3, exit #for(int i = $a2, i < num_rows; i++)

	col_iterator:
		bge $a3, $s4, row_increment #for(int j = $a3, j < num_col; j++)
		#mul $s0, $a2, 4
		mul $s0, $a2, $s4 #&puzzle_grid[i]
		#lw $s0, 0($s0) #puzzle_grid[i]
		#mul $s6, $a3, 4
		add $s0, $a3, $s0 #calculate ((4i * num_cols) + j)
		add $s0, $s0, $a0 #add this address to puzzle_grid to get &puzzle_grid[i][j]
		lb $s1, 0($s0) #puzzle_grid[i][j]
		beq $s1, $s2, exit #if(puzzle_grid[i][j] == puzzle_word[0]) then break

		addi $a3, $a3, 1
		j col_iterator #increment j

	row_increment:
		addi $a2, $a2, 1
		j row_iterator #increment i

	#found the row and col at this point
	exit:
		#all the $a registers should be set up at this point
		jal search_neighbors
		sw $v0, SUBMIT_SOLUTION

		#Reset the static pointer
		lw $ra, 0($sp)
		lw $s0, 4($sp)
		lw $s1, 8($sp)
		lw $s2, 12($sp)
		lw $s3, 16($sp)
		lw $s4, 20($sp)
		lw $s5, 24($sp)
		lw $s6, 28($sp)
		add $sp, $sp, 32

		j wait

############################################################

#END OF PUZZLE CODE

############################################################

############################################################

.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 16	# space for two registers

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
	sw  $a2, 8($k0)   
	sw 	$a3, 12($k0)


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
	and $a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne $a0, 0, request_puzzle_interrupt

	#li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

fruit_smooshed_interrupt:

	la $t6, count # count address
	lw $t7, 0($t6) # count value
	addi $t7, $t7, 1 #increment it
	sw $t7, 0($t6) #store it back in 

	la $t8, SMASH_TOTAL
	lw $t8, 0($t8)
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

	li $t9, 0

	j bonk_interrupt


request_puzzle_interrupt:
	
	la $a2, puzzle_received_flag
	lw $a2, 0($a2)
	bne $a2, $zero, interrupt_dispatch #if puzzle_received_flag != 0 don't do anything

	#Actually set puzzle_received_flag to 1
	li $a3, 1
	la $a2, puzzle_received_flag
	sw $a3, 0($a2)

	la $a3, puzzle_word
	sw $a3, REQUEST_WORD

	sw $a1, REQUEST_PUZZLE_ACK

	j interrupt_dispatch


smashing:
	sw $zero, 0($t6) #smash

	add $t8, $t8, 1

	la $t9, SMASH_TOTAL
	lw $t9, 0($t9)

	blt $t8, $t9, smashing #smash the total number we want

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
	lw $a2, 8($k0)
	lw $a3, 12($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret