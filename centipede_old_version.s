# CSC258H Winter 2021 Final Assembly Project
# University of Toronto, St. George
#
# Angela Xin Zhang, 1005703516
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8					     
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Milestone 3

.data
	displayAddress: .word 0x10008000
	
	# colors
	backgroundColor: .word 0x000000
	textColor: .word 0xffffff
	centipedeBodyColor: .word 0xe95546
	centipedeHeadColor: .word 0xff0000
	mushroomColor: .word 0xf9ea44
	fleaColor: .word 0xdf16c6
	bulletColor: .word 0x90eeec
	bugBlasterColor: .word 0x19b6ea
	
	# starting positions
	centipedeLocation: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
	centipedeHeadLocation: .word 9 # the x location of the centipede's head
	# centipedeHeadYLocation: .word 0 # the y location of the centipede's head
	bugBlasterLocation: .word 816
	
	# centipede motion parameters
	centipedeDirection: .word 1 #parameter designating centipede's direciton, 1 for right, 0 for stop, -1 for left
	leftBound: .word 0 #left bound where centipede will change direction
	rightBound: .word 31 #right bound wehre centipede will change direction
	
.text

##### Initializations #####
##### s0 stores the centipede's location
##### s1 stores the bug blaster location
##### s2 stores the dart location
##### S3 and S4 respectively stores the left and right bounds of the current row of the screen that the centipede is on.
##### S5 stores the direction of the centipede's head
##### s6 stores whether or not the centipede has hit a mushroom, 0 means it didn't, 1 means it did
##### s7 stores the location of a flea
##### v1 will store the previous bug blaster location

init:
	lw $s0, centipedeHeadLocation
	lw $s1, bugBlasterLocation
	lw $s3, leftBound #left bound at zero
	lw $s4, rightBound #right bound at 31
	lw $s5, centipedeDirection # initial direction is headed to the right
	add $v1, $v1, $s1 #set v1 also to bugBlasterLocation
	jal draw_centipede

##### Game Loop #####
game_loop:

	# draw mushrooms
	jal draw_mushrooms
	
	# draw bug blaster
	jal draw_bug_blaster
	
	# check for keyboard input 
	lw $t1, 0xffff0000 # check MMIO for keypress
	beq $t1, 1, keyboard_input
	j keyboard_input_done # jump past keyboard_input function if no input detected.
	
	keyboard_input:
		lw $t1, 0xffff0004 # read the input into $t1
		beq $t1, 0x6A, respond_to_j
		beq $t1, 0x6B, respond_to_k
		beq $t1, 0x78, respond_to_x
	
		respond_to_j:
			move $v1, $s1 # store the old bug blaster location at v1 address
			addi $s1, $s1, -1 # move bug blaster left
			j keyboard_input_done
	
		respond_to_k:
			move $v1, $s1 # store the old bug blaster location at v1 address
			addi $s1, $s1, 1 # move bug blaster right
			j keyboard_input_done
	
		respond_to_x:
		
			j keyboard_input_done
	
	keyboard_input_done:
		# does nothing
		
	# move centipede
	centipede_move:
		beq $s5, 1, centipede_move_right
		beq $s5, 0, centipede_stop_move
		beq $s5, -1, centipede_move_left
		
		#s5 is initially 1, so it moves right first.
		centipede_move_right:
			beq $s0, $s4, centipede_stop_move #stop centipede from moving once it hits right bound
			jal detect_mushroom_hit
			beq $s6, 1, centipede_stop_move #if mushroom is hit
			add $t9, $s0, $zero # store the last place the centipede passed through in t9
			addi $s0, $s0, 1
			j centipede_move_end

		centipede_stop_move:
			addi $s0, $s0, 0
			# The centipede stops because it either:
			# - reached the same row as the Bug Blaster
			# - reached the end of a row
			# - reached a mushroom
			
			# if the reached the Bug Blaster run stop_centipede - centipede restricted to the row
			beq $s0, 0x0000033f, stop_centipede
			beq $s0, 800, stop_centipede
					
			# otherwise keep going
			add $t9, $s0, $zero #store the last place the centipede passed through in t9
			addi $s3, $s3, 32 # add 32 to left bound to get new left bound
			addi $s4, $s4, 32 # add 32 to right bound to get new right bound
			addi $s0, $s0, 32 # transfer centipede down by one row.
			beq $s0, $s3, centipede_change_right #change centipede's direction to right since it hit left bound
			beq $s0, $s4, centipede_change_left #change centipede's direction to left since it hit right bound.
			beq $s6, 1, mushroom_change_direction # change direction because it hit a mushroom.
		
		centipede_move_left:
			beq $s0, $s3, centipede_stop_move #stops the centipede from moving once it hits the left bound
			jal detect_mushroom_hit
			beq $s6, 1, centipede_stop_move #if mushroom is hit
			add $t9, $s0, $zero #store the last place the centipede passed through in t9
			addi $s0, $s0, -1
			
			j centipede_move_end

centipede_move_end:
	# We've finished updating location and direction of the centipede, so draw the centipede to new location
	#jal draw_centipede_head
	jal draw_centipede

	# Delay before restarting loop
	li $v0, 32				# Sleep op code
	li $a0, 50				# Sleep 1/20 second 
	syscall

	j game_loop


##### Centipede Direction Changes #####
centipede_change_left: 
	addi $s5, $s5, -2
	j centipede_move_end

centipede_change_right: 
	addi $s5, $s5, +2
	j centipede_move_end

stop_centipede:
	# centipede is stopped in one row, going back and forth
	blt $s5, $zero, centipede_change_right
	bgt $s5, $zero, centipede_change_left

freeze_centipede:
	# centipede completely stops (currently not called anywhere by the game loop)
	blt $s5, $zero, add_to_direction
	add_to_direction:
		addi $s5, $s5, 1
	bgt $s5, $zero, subtract_from_direction
	subtract_from_direction:
		addi $s5, $s5, -1


##### Draw Centipede #####
draw_centipede:
	addi $a0, $zero, 9 # store loop count in a0

draw_centipede_loop:
	beq $a0, 9, draw_centipede_head
	bne $a0, 9, draw_centipede_body

draw_centipede_head:
	# paint new block centipede color
	lw $t1, centipedeHeadColor
	lw $t2, backgroundColor
	sll $t7, $s0, 2 # t7 = the offset of the head
	add $t8, $t7, $gp # address of new block
	sw $t1, 0($t8) # color in new block with head color
	
	# paint past block background color
	sll $t7, $t9, 2 # t9 = where we want to paint the next block, in this case it's the location of the old head
	add $t8, $t7, $gp # t8 = address of past block
	sw $t2, 0($t8) # color in past block with background color
	
	add $t6, $s0, $zero # t6 is the location of whichever block has last been drawn. store head to t6.
	
	addi $a0, $a0, -1 # decrement loop count
	j draw_centipede_loop
	
	
draw_centipede_body:
	lw $t1, centipedeBodyColor #t1 stores body color
	lw $t2, backgroundColor #t2 stores background color
	#t9 still stores past block location at this point.
	sll $t7, $t9, 2 # t9 = location of block to be painted next, t7 is the offset of this block, new body segment goes here
	add $t8, $t7, $gp # t8 = address of the past block
	sw $t1, 0($t8) # color in this block with body segment color
	
	sub $t3, $t6, $t9 # t3 = last location t6 - current block location t9
	sub $t6, $t6, $t6
	add $t6, $t6, $t9 # update the last drawn block with this block's location
	
	ble $t3, 9, draw_body_same_direction # if head - current block <= 9 units away, then draw in the same direction as the centipede's head
	beq $t3, 32, draw_body_at_location # if head and body is exactly 32 units away, then draw at the location
	bgt $t3, 9, draw_body_diff_direction # if head - current block > 9 units away, then draw in the direction opposite its head.
	
	addi $a0, $a0, -1 # decrement loop count
	bne $a0, $zero, draw_centipede_loop #go back to loop if loop count is not zero
	beq $a0, $zero, drawing_done # go to drawing_done, conclude the loop.
	
	draw_body_same_direction:
		# store the next body segment location in t9, corresponding to s5 direction
		beq $s5, 1, draw_same_right
		beq $s5, -1, draw_same_left
	
		draw_same_right:
			addi $t9, $t9, -1
		
		draw_same_left:
			addi $t9, $t9, 1
	
		addi $a0, $a0, -1 # decrement loop count
		bne $a0, $zero, draw_centipede_loop #go back to loop if loop count is not zero
		beq $a0, $zero, drawing_done # go to drawing_done, conclude the loop.
	
	draw_body_diff_direction:
		# store the next body segment location in t9, opposite of s5 centipede head direction
		beq $s5, 1, draw_diff_right
		beq $s5, -1, draw_diff_left
	
		draw_diff_right:
			addi $t9, $t9, 1
	
		draw_diff_left:
			addi $t9, $t9, -1

		addi $a0, $a0, -1 # decrement loop count
		bne $a0, $zero, draw_centipede_loop #go back to loop if loop count is not zero
		beq $a0, $zero, drawing_done # go to drawing_done, conclude the loop.
	
	draw_body_at_location:
		addi $t9, $t9, 32
		addi $a0, $a0, -1 # decrement loop count
		bne $a0, $zero, draw_centipede_loop #go back to loop if loop count is not zero
		beq $a0, $zero, drawing_done # go to drawing_done, conclude the loop.
	
			
drawing_done:
	# paint the block centipede went over background color
	sll $t7, $t9, 2 # t9 = last location of the head block, t7 is the offset of the last block
	add $t8, $t7, $gp # t8 = address of past block
	sw $t2, 0($t8) # color in past block with background color
	jr $ra


##### Mushrooms #####
draw_mushrooms:
	#draw a couple of mushrooms to the display, hardcoded in for demonstration purposes
	lw $t5, displayAddress
	lw $t4, mushroomColor
	sw $t4, 320($t5)
	sw $t4, 600($t5)
	sw $t4, 1200($t5)
	sw $t4, 2600($t5)
	sw $t4, 2020($t5)
	
	jr $ra # returns to game_loop
	
detect_mushroom_hit:
	beq $t1, 1, detect_mushroom_hit_r_direction #if centipede direction is right, detect if mushroom is hit from left side
	beq $t1, -1, detect_mushroom_hit_l_direction #if centipede direction is left, detect if mushroom is hit from right side.

detect_mushroom_hit_r_direction:
	addi $t3, $s0, 1 #store the next place the centipede will move to if it's going right, in t3
	beq $t3, 0x00000050, mushroom_hit #mushroom is hit when if any of the mushroom positions are in he immediate future position
	beq $t3, 0x00000096, mushroom_hit
	beq $t3, 0x0000012c, mushroom_hit
	beq $t3, 0x000001f9, mushroom_hit
	beq $t3, 0x0000028a, mushroom_hit
	jr $ra

detect_mushroom_hit_l_direction:
	addi $t3, $s0, -1 #store the next place the centipede will move to if it's going left, in t3
	beq $t3, 0x00000050, mushroom_hit
	beq $t3, 0x00000096, mushroom_hit 
	beq $t3, 0x0000012c, mushroom_hit
	beq $t3, 0x000001f9, mushroom_hit
	beq $t3, 0x0000028a, mushroom_hit
	jr $ra

mushroom_hit:
	addi $s6, $s6, 1
	jr $ra

reset_mushroom_hit:
	addi $s6, $s6, -1
	jr $ra
	
mushroom_change_direction:
	addi $s6, $s6, -1 # reset whether if mushroom is hit or not
	beq $s5, 1, centipede_change_left
	beq $s5, -1, centipede_change_right

##### Bug Blaster #####

draw_bug_blaster:
	#draw bug blaster for demonstratiion purposes
		
	lw $t4, bugBlasterColor
	sll $t6, $s1, 2 # offset of bug blaster location
	add $t7, $t6, $gp # address of the bug blaster on display
	sw $t4, 0($t7) # paint the new bug
	
	bne $s1, $v1, paint_background_after_bug # if bug blaster has moved, paint background color in the old bug location.
	
	jr $ra # go back to game_loop
	
	paint_background_after_bug:
		lw $t4, backgroundColor
		sll $t6, $v1, 2 # offset of previous bug blaster location
		add $t7, $t6, $gp # address of the previous bug blaster location on display
		sw $t4, 0($t7) # paint it background colored
		
		jr $ra
	

# check_keystroke:

# get_key_input:

	
##### Exit #####

Exit:
	li $v0, 10		# terminate the program gracefully
	syscall
