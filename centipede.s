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
# Milestone 1

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
	centipedeHeadYLocation: .word 0 # the y location of the centipede's head
	bugBlasterLocation: .word 814
	
	# centipede motion parameters
	centipedeDirection: .word 1 #parameter designating centipede's direciton, 1 for right, 0 for stop, -1 for left
	leftBound: .word 0 #left bound where centipede will change direction
	rightBound: .word 31 #right bound wehre centipede will change direction
	
.text

##### Initializations #####
##### For faster access, centipede location is stored in s0, s1, and s2.
##### S3 and S4 respectively stores the left and right bounds of the current row of the screen that the centipede is on.
##### S5 stores the direction of the centipede's head
##### s6 stores whether or not the centipede has hit a mushroom, 0 means it didn't, 1 means it did.
##### s0 for x locations, s1 for y locations, s2 for move time.

init:
	lw $s0, centipedeHeadLocation
	lw $s3, leftBound #left bound at zero
	lw $s4, rightBound #right bound at 31
	lw $s5, centipedeDirection # initial direction is headed to the rightright

##### Game Loop #####
game_loop:

	# draw mushrooms
	jal draw_mushrooms
	
	# draw bug blaster
	jal draw_bug_blaster
	
	# move centipede head
	# beq $s0, 800
	
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
			# now that the centipede is stopped, it means it's either:
			# - reached the edge of the diaply
			# - reached the end of a row
			# - reached a mushroom
			
			# if the reached the end of the display, stop entirely.
			beq $s0, 0x0000033f, stop_centipede
			beq $s0, 800, stop_centipede
					
			# otherwies keep going
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
	
	# draw centipede
	#jal display_centipede

centipede_change_left: 
	addi $s5, $s5, -2
	j centipede_move_end

centipede_change_right: 
	addi $s5, $s5, +2
	j centipede_move_end

stop_centipede: # make the centipede go back and forth
	#blt $s5, $zero, add_to_direction # make the direction 0.
	#add_to_direction:
	#	addi $s5, $s5, 1
	#bgt $s5, $zero, subtract_from_direction
	#subtract_from_direction:
	#	addi $s5, $s5, -1
	
	blt $s5, $zero, centipede_change_right
	bgt $s5, $zero, centipede_change_left
	
	
centipede_move_end:
	jal draw_centipede_head_1
	#jal draw_centipede

	# Delay before restarting loop
	li $v0, 32				# Sleep op code
	li $a0, 50				# Sleep 1/20 second 
	syscall

	j game_loop

draw_centipede:
	addi $a0, $zero, 10 # store loop count in a0

draw_centipede_loop_1:
	bne $a0, 1, draw_centipede_body_1
	beq $a0, 1, draw_centipede_head_1

draw_centipede_head_1:
	# paint new block centipede color
	lw $t1, centipedeHeadColor
	lw $t2, backgroundColor
	sll $t7, $s0, 2 
	add $t8, $t7, $gp # address of new block
	sw $t1, 0($t8) # color in new block with head color
	
	# paint past block background color
	sll $t7, $t9, 2
	add $t8, $t7, $gp # address of past block in t8
	sw $t2, 0($t8) # color in past block with background color
	
	jr $ra
	
draw_centipede_body_1:
	# does nothing atm
		
###### Draw Centipede #####
display_centipede:
	# sw $t1, 40($t0) # paint the 10th block of the display the color of the centipede's head.
	# sw $t2, 0($t0) # paint the centipede's body
	
	addi $a0, $zero, 10 # store loop count in a0
	la $a1, centipedeLocation #load centipedeLocation array into a1

draw_centipede_loop: # loop to draw the full centipede
	bne $a0, 1, draw_centipede_body #if the counter is not at the last segment, draw body parts
	beq $a0, 1, draw_centipede_head #if the counter is at the last segment, draw head part
	
draw_centipede_body:
	lw $t1, centipedeBodyColor # load centipedeBodyColor to t1
	lw $t2, 0($a1) # load a segment from the centipedeLocation array to t2
	
	# draw the body
	sll $t2, $t2, 2 #t2 is the offset
	add $t4, $t2, $gp # t4 = offset + $gp, the address on the display
	sw $t1, 0($t4) # color the address on the display body color.
	addi $a1, $a1, 4 # point to the next element in the array.
	
	# loop back
	addi $a0, $a0, -1 # decrement loop count
	bne $a0, $zero, draw_centipede_loop # loop if counter not yet 0
	
draw_centipede_head:
	lw $t1, centipedeHeadColor # load centipedeHeadColor to t1
	lw $t2, 0($a1) # load a segment from the centipedeLocation array to t2
	
	# draw the head
	sll $t2, $t2, 2 # t2 is offset
	add $t4, $t2, $gp # t4 = offset + $gp, t4 is now the address on the display
	sw $t1, 0($t4) # color the address on the display head colored
	addi $a0, $a0, -1
	# since the counter has to be 0 at this point, we can proceed with the instructions.
	
	jr $ra # return after doing the entire display centipede thing.


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
	
	jr $ra
	
detect_mushroom_hit:
	beq $s5, 1, detect_mushroom_hit_r_direction #if centipede direction is right, detect if mushroom is hit from left side
	beq $s5, -1, detect_mushroom_hit_l_direction #if centipede direction is left, detect if mushroom is hit from right side.

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
	lw $t5, displayAddress
	lw $t4, bugBlasterColor
	sw $t4, 3264($t5)
	
	jr $ra



##### Centipede Movement #####

#to prevent bugs, prevent data from overlapping on the display,
# I think if the centipede reaches the bottom of the screen, it will go around in a circle
# move until the end of the screen, and then move down, and then move the opposite direction.

#display_blaster:

# check_keystroke:

# get_key_input:

	
##### Exit #####

Exit:
	li $v0, 10		# terminate the program gracefully
	syscall


	
	
	
