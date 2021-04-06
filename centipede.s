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
	dartColor: .word 0x90eeec
	bugBlasterColor: .word 0x19b6ea
	
	# starting positions
	centipedeLocations: .word 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
	centipedeHeadLocation: .word 9 # the x location of the centipede's head
	bugBlasterLocation: .word 816
	
	# centipede motion parameters
	centipedeDirection: .word 1 #parameter designating centipede's direciton, 1 for right, 0 for stop, -1 for left
	centipedeDirections: .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	leftBound: .word 0 #left bound where centipede will change direction
	rightBound: .word 31 #right bound wehre centipede will change direction
	
.text

##### Initializations #####
##### s0 stores the centipede's locations
##### s1 stores the bug blaster location
##### s2 stores the dart location
##### S3 and S4 respectively stores the left and right bounds of the current row of the screen that the centipede is on.
##### S5 stores the centipede's direction
##### s6 stores progress towards victory
##### s7 stores the location of a flea
##### v1 will store the previous bug blaster location

# Fill the screen with background color
draw_bg:
	lw $t0, displayAddress		# Location of current pixel data
	addi $t1, $t0, 4096		# Location of last pixel data. Hard-coded, 32x32 = 1024 pixels x 4 bytes = 4096.
	lw $t2, backgroundColor		# Colour of the background
	
draw_bg_loop:
	sw $t2, 0($t0)				# Store the colour
	addi $t0, $t0, 4			# Next pixel
	blt $t0, $t1, draw_bg_loop

init:
	la $s0, centipedeLocations
	lw $s1, bugBlasterLocation
	move $s2, $zero # set dart location to 0 to begin with
	lw $s3, leftBound # left bound at 0
	lw $s4, rightBound # right bound at 31
	la $s5, centipedeDirections
	move $s6, $zero # set victory condition to zero to begin with
	add $v1, $v1, $s1 # set v1 also to bugBlasterLocation
	jal generate_random_flea_pos
	jal draw_centipede # draw the initial centipede on screen.
	

##### Game Loop #####
game_loop:
	
	beq $s7, $s1, game_over_screen # check game over condition
	bge $s6, 3, win_screen # check victory condition - centipede has been hit 3 times
	
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
		j keyboard_input_done
	
		respond_to_j:
			move $v1, $s1 # store the old bug blaster location at v1 address
			addi $s1, $s1, -1 # move bug blaster left
			j keyboard_input_done
	
		respond_to_k:
			move $v1, $s1 # store the old bug blaster location at v1 address
			addi $s1, $s1, 1 # move bug blaster right
			j keyboard_input_done
	
		respond_to_x:
			bgt $s2, 0, keyboard_input_done
			addi $v1, $s1, -32
			move $s2, $v1
	
	keyboard_input_done:
		# nothing, move on
		
	# move dart, draw dart
	move_dart:
		ble $s2, $zero, dart_move_done # flea has gone off screen
		addi $s2, $s2, -32
		jal draw_dart
	
	bgt $s2, $zero, _next_move_flea # if there is still a moving dart, keep going
	dart_move_done:
		move $s2, $zero
		
	_next_move_flea:
		#nothing, move on
		
	# move flea, draw flea
	move_flea:
		bge $s7, 0x0000044f, flea_move_done # flea has gone off screen
		addi, $s7, $s7, 32
		jal draw_flea
	
	blt $s7, 0x0000044f, _next
	
	flea_move_done:
		jal generate_random_flea_pos
	
	_next:
		# nothing, move on
	
	# move centipede
	addi $a0, $zero, 10 #store loop count in a0
	lw $t0, 0($s0) # load a word from centipede locations into t0
	add $t9, $t0, $zero #store the last place the centipede passed through in t9
	lw $t1, 0($s5) # load a word from centipede directions into t1
	
	arr_loop:
		# goes through the centipede location and direction arrays and updates new values.
		lw $t0, 0($s0) # load a word from centipede locations into t0
		lw $t1, 0($s5) # load a word from centipede directions into t1
		
		bne $s2, $t0, _no_dart_hit # if no darts hit the centipede keep going
		addi $s6, $s6, 1 # otherwise add 1 to s1
		
		_no_dart_hit:
			#nothing, move on
		
	centipede_move: 
		
		beq $t1, 1, centipede_move_right
		beq $t1, 0, centipede_stop_move
		beq $t1, -1, centipede_move_left
		
		centipede_move_right:
			#jal detect_mushroom_hit
			beq $t0, $s4, centipede_stop_move #stop centipede from moving once it hits right bound
			#add $t9, $s0, $zero # store the last place the centipede passed through in t9
			addi $t0, $t0, 1
			sw $t0, 0($s0) # stores new position in s0
			
			j next_loop
			
		centipede_move_left:
			#jal detect_mushroom_hit
			beq $t0, $s3, centipede_stop_move #stop centipede from moving once it hits left bound
			#add $t9, $t0, $zero #store the last place the centipede passed through in t9
			addi $t0, $t0, -1
			sw $t0, 0($s0)
			
			j next_loop
			
		centipede_stop_move:
			# The centipede stops because it either:
			# - reached the same row as the Bug Blaster
			# - reached the end of a row
			# - reached a mushroom
			
			# if the reached the Bug Blaster run stop_centipede - centipede restricted to the row
			beq $s0, 0x0000033f, stop_centipede
			beq $s0, 800, stop_centipede
					
			# otherwise keep going
			addi $t0, $t0, 32 # transfer centipede down by one row.
			sw $t0, 0($s0)
			addi $s3, $s3, 32 # new bounds
			addi $s4, $s4, 32 # new bounds
			beq $t0, $s3, centipede_change_right #change centipede's direction to right since it hit left bound
			beq $t0, $s4, centipede_change_left #change centipede's direction to left since it hit right bound.
			beq $s6, 1, mushroom_change_direction # change direction because it hit a mushroom.
			
			centipede_change_right:
				addi $t1, $t1, +2
				sw $t1, 0($s5)
				j next_loop
			
			centipede_change_left:
				addi $t1, $t1, -2
				sw $t1, 0($s5)
				j next_loop
		
		next_loop:
			addi $s0, $s0, 4 # point to next element
			addi $s5, $s5, 4
			
			
			addi $a0, $a0, -1 # decrement loop count
			
			beq $a0, $zero centipede_move_end
			bne $a0, $zero arr_loop
		
	
centipede_move_end:
	# We've finished updating location and direction of the centipede, so draw the centipede to new location
	#jal draw_centipede_head
	la $s0, centipedeLocations # reset array pointer to first element
	la $s5, centipedeDirections # reset array pointer to first element
	jal draw_centipede

	# Delay before restarting loop
	li $v0, 32				# Sleep op code
	li $a0, 50				# Sleep 1/20 second 
	syscall

	j game_loop


##### Centipede Direction Changes #####

stop_centipede:
	# centipede is stopped in one row, going back and forth
	blt $t0, $zero, centipede_change_right
	bgt $t0, $zero, centipede_change_left


##### Draw Centipede #####
draw_centipede:
	addi $a0, $zero, 0 # store loop count in a0

draw_centipede_loop:
	beq $a0, 9, draw_centipede_head # if a0 = 9, draw the centipede head
	bne $a0, 9, draw_centipede_body # if a0 != 9, draw the centipede body segment
	
draw_centipede_body:
	# paint a block the color of the centipede body
	bne $a0, 0, draw_body_seg
	
	draw_body_seg:	
		lw $t0, centipedeBodyColor
		lw $t1, 0($s0) # load a word from centipede locations array
		sll $t2, $t1, 2 # store the offset in t2
		add $t2, $t2, $gp # store address on display in t2
		sw $t0, 0($t2)
		addi $s0, $s0, 4 # point to next element
		
		addi $a0, $a0, 1 # increase loop count
		j draw_centipede_loop
	
draw_centipede_head:
	# paint a block the color of the centipede head
	lw $t0, centipedeHeadColor
	lw $t1, 0($s0) # load word from centipede locations array
	sll $t2, $t1, 2 # store the offset in t2
	add $t2, $t2, $gp # store address on display in t2
	sw $t0, 0($t2)
	
	addi $s0, $s0, -36 # reset pointer to the beginning of the array
	
	bge $a0, 9 drawing_done # head is last to be drawn, so finish the drawing.
	
drawing_done:
	# paint in the background after the centipede as moved
	lw $t0, backgroundColor
	sll $t1, $t9, 2 # t1 stores offset of the location that is stored in t9
	add $t2, $t1, $gp # t2 stores the address of the past location
	sw $t0, 0($t2) # paint the block on the display background colored
	
	addi $a0, $a0, -9 # resets loop count
	
	jr $ra # jump back to wherever it is that last called draw_centipede.
				
	

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
	addi $t3, $t0, 1 #store the next place the centipede will move to if it's going right, in t3
	beq $t3, 0x00000096, mushroom_hit #mushroom is hit when if any of the mushroom positions are in he immediate future position
	beq $t3, 0x00000050, mushroom_hit
	beq $t3, 0x0000012c, mushroom_hit
	beq $t3, 0x000001f9, mushroom_hit
	beq $t3, 0x0000028a, mushroom_hit
	jr $ra

detect_mushroom_hit_l_direction:
	addi $t3, $t0, -1 #store the next place the centipede will move to if it's going left, in t3
	beq $t3, 0x00000096, mushroom_hit
	beq $t3, 0x00000050, mushroom_hit 
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
	# draw bug blaster
		
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
		
draw_dart:
	lw $t0, dartColor
	sll $t6, $s2, 2
	add $t7, $t6, $gp
	sw $t0, 0($t7)
	
	paint_background_after_dart:
		lw $t4, backgroundColor
		addi $t5, $s2, 32
		sll $t6, $t5, 2
		add $t7, $t6, $gp
		sw $t4, 0($t7)
		
		jr $ra

##### Flea #####

# create a flea
generate_random_flea_pos:
	li $v0, 42
	li $a0, 0
	li $a1, 31
	syscall
		
	move $s7, $a0
	jr $ra
	
	
draw_flea:
	lw $t0, fleaColor
	sll $t6, $s7, 2
	add $t7, $t6, $gp
	sw $t0, 0($t7)
	
	paint_background_after_flea:
		lw $t4, backgroundColor
		addi $t5, $s7, -32
		sll $t6, $t5, 2
		add $t7, $t6, $gp
		sw $t4, 0($t7)
		
		jr $ra
		
##### Game End Screens #####
#Win
win_screen:
	lw $t1, textColor
	# w
	sw $t1, 292($gp)
	sw $t1, 308($gp)
	sw $t1, 420($gp)
	sw $t1, 428($gp)
	sw $t1, 436($gp)
	sw $t1, 552($gp)
	sw $t1, 560($gp)
	# i
	sw $t1, 316($gp)
	sw $t1, 572($gp)
	sw $t1, 700($gp)
	# n
	sw $t1, 452($gp)
	sw $t1, 456($gp)
	sw $t1, 460($gp)
	sw $t1, 580($gp)
	sw $t1, 592($gp)
	sw $t1, 708($gp)
	sw $t1, 720($gp)
	
	lw $t2, 0xffff0000 # check MMIO for keypress
	bne $t2, 1, win_screen_next
	
	win_restart: # restart if r key is pressed
		lw $t2, 0xffff0004 # read the input into $t2
		beq $t2, 0x72, draw_bg # go all the way back to beginning and restart game if r is pressed.
	
	win_screen_next:
	
	li $v0, 32 # sleep before looping
	li $a0, 1000
	j win_screen
	
#Rip
game_over_screen:
	lw $t1, textColor
	#r
	sw $t1, 300($gp)
	sw $t1, 304($gp) 
	sw $t1, 308($gp)
	sw $t1, 424($gp)
	sw $t1, 552($gp)
	sw $t1, 680($gp)
	#i
	sw $t1, 316($gp)
	sw $t1, 572($gp)
	sw $t1, 700($gp)
	#p
	sw $t1, 324($gp)
	sw $t1, 328($gp)
	sw $t1, 332($gp)
	sw $t1, 452($gp)
	sw $t1, 460($gp)
	sw $t1, 580($gp)
	sw $t1, 588($gp)
	sw $t1, 708($gp)
	sw $t1, 712($gp)
	sw $t1, 836($gp)
	
	lw $t2, 0xffff0000 # check MMIO for keypress
	bne $t2, 1, game_over_next
	
	game_over_restart: # restart if r key is pressed
		lw $t2, 0xffff0004 # read the input into $t2
		beq $t2, 0x72, draw_bg # go all the way back to beginning and restart game if r is pressed.
	
	game_over_next:
	
	li $v0, 32 # sleep before looping
	li $a0, 1000
	j game_over_screen


##### Exit #####

Exit:
	li $v0, 10		# terminate the program gracefully
	syscall
