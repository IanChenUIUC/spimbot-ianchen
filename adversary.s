.text             
        PRINT_STRING = 4
        PRINT_CHAR = 11
        PRINT_INT = 1


        VELOCITY  = 0xffff0010
        ANGLE     = 0xffff0014
        ANGLE_CONTROL = 0xffff0018

        BOT_X     = 0xffff0020
        BOT_Y     = 0xffff0024

        OTHER_X   = 0xffff00a0
        OTHER_Y   = 0xffff00a4

        TIMER     = 0xffff001c

        REQUEST_PUZZLE = 0xffff00d0     ## Puzzle
        SUBMIT_SOLUTION = 0xffff00d4    ## Puzzle

        SCORES_REQUEST = 0xffff1018
        GET_MY_BULLETS = 0xffff2010
        GET_OP_BULLETS = 0xffff200c
        GET_MAP   = 0xffff2040

        CHARGE_SHOT = 0xffff2004
        SHOOT     = 0xffff2000

        BONK_INT_MASK = 0x1000          ## Bonk
        BONK_ACK  = 0xffff0060          ## Bonk

        TIMER_INT_MASK = 0x8000         ## Timer
        TIMER_ACK = 0xffff006c          ## Timer

        REQUEST_PUZZLE_INT_MASK = 0x800 ## Puzzle
        REQUEST_PUZZLE_ACK = 0xffff00d8 ## Puzzle
        
        GRIDSIZE = 4                    ## Sudoku
        GRID_SQUARED = 16
        ALL_VALUES = 65535

        RESPAWN_INT_MASK = 0x2000       ## Respawn
        RESPAWN_ACK = 0xffff00f0        ## Respawn



.data             
        board:     .space 512
        interrupt_struct: .byte 0 0 0 0
        ### Puzzle
        symbollist:       .byte '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' 'A' 'B' 'C' 'D' 'E' 'F' 'G'
        #### Puzzle
        has_puzzle: .word 0
        has_timer: .byte 0
        has_bonked: .byte 0
.text             

        .align    2
        .globl    printInt
printInt:         
        move      $v1,$a0
        move      $a0, $v1
        li        $v0, 1
        syscall   
        j         $ra
        .align    2
        .globl    printChar
printChar:        
        move      $v1,$a0
        move      $a0, $v1
        li        $v0, 11
        syscall   
        j         $ra
        .align    2
        .globl    printString
printString:      
        move      $v1,$a0
        move      $a0, $v1
        li        $v0, PRINT_STRING
        syscall   
        j         $ra
        .align    2
        .globl    rng
rng:              
        la        $a0,rng_state
        lw        $v0,0($a0)
        sll       $v1,$v0,13
        xor       $v1,$v1,$v0
        srl       $v0,$v1,17
        xor       $v1,$v0,$v1
        sll       $v0,$v1,5
        xor       $v0,$v0,$v1
        sw        $v0,0($a0)
        j         $ra
        .align    2
        .globl    setVelocity
setVelocity:      
        sw        $a0, VELOCITY

        j         $ra
        .align    2
        .globl    getVelocity
getVelocity:      
        lw        $v0, VELOCITY

        j         $ra
        .align    2
        .globl    getBotPxX
getBotPxX:        
        lw        $v0, BOT_X

        j         $ra
        .align    2
        .globl    getBotPxY
getBotPxY:        
        lw        $v0, BOT_Y

        j         $ra
        .align    2
        .globl    getBotX
getBotX:          
        lw        $v0, BOT_X

        srl       $v0,$v0,3
        j         $ra
        .align    2
        .globl    getBotY
getBotY:          
        lw        $v0, BOT_Y

        srl       $v0,$v0,3
        j         $ra
        .align    2
        .globl    getOpPxX
getOpPxX:         
        lw        $v0, OTHER_X

        j         $ra
        .align    2
        .globl    getOpPxY
getOpPxY:         
        lw        $v0, OTHER_Y

        j         $ra
        .align    2
        .globl    getOpX
getOpX:           
        lw        $v0, OTHER_X

        srl       $v0,$v0,3
        j         $ra
        .align    2
        .globl    getOpY
getOpY:           
        lw        $v0, OTHER_Y

        srl       $v0,$v0,3
        j         $ra
        .align    2
        .globl    getOrientation
getOrientation:   
        lw        $v0, ANGLE

        j         $ra
        .align    2
        .globl    setAbsoluteOrientation
setAbsoluteOrientation: 
        sw        $a0, ANGLE
        li        $a0, 1
        sw        $a0, ANGLE_CONTROL

        j         $ra
        .align    2
        .globl    setRelativeOrientation
setRelativeOrientation: 
        sw        $a0, ANGLE
        sw        $0, ANGLE_CONTROL

        j         $ra
        .align    2
        .globl    getScores
getScores:        
        la        $v0,bot_scores
        sw        $v0, SCORES_REQUEST
        j         $ra
        .align    2
        .globl    getMyBullets
getMyBullets:     
        la        $v0,my_bullets
        sw        $v0, GET_MY_BULLETS
        j         $ra
        .align    2
        .globl    getOpBullets
getOpBullets:     
        la        $v0,op_bullets
        sw        $v0, GET_OP_BULLETS
        j         $ra
        .align    2
        .globl    getMap
getMap:           
        la        $v0,game_map
        sw        $v0, GET_MAP
        j         $ra
        .align    2
        .globl    getMapAt
getMapAt:         
        sw        $a0, GET_MAP
        j         $ra
        .align    2
        .globl    submitPuzzle
submitPuzzle:     
        sw        $a0, SUBMIT_SOLUTION
        j         $ra
        .align    2
        .globl    charge_shot
charge_shot:      
        sw        $a0, CHARGE_SHOT
        j         $ra
        .align    2
        .globl    shoot
shoot:            
        sw        $a0, SHOOT
        j         $ra
        .align    2
        .globl    getTimer
getTimer:         
        lw        $v0, TIMER
        j         $ra
        .align    2
        .globl    requestTimer
requestTimer:     
        lw        $v0, TIMER
        addu      $a0,$a0,$v0
        sw        $a0, TIMER
        j         $ra
        .align    2
        .globl    sleep
sleep:            
        lw        $v0,TIMER
        add       $a0,$v0,$a0
        bgt       $v0,$a0,$sleep405_loop_skip
$sleep405_loop:   
        lw        $v0,TIMER
        blt       $v0,$a0,$sleep405_loop
$sleep405_loop_skip: 

        j         $ra
        .align    2
        .globl    initSolver
initSolver:       
        la        $v0,puzzle_request_dest
        sw        $v0, REQUEST_PUZZLE
        j         $ra

    .align    2
    .globl quant_solve
quant_solve:
    sub  $sp, $sp, 28
    sw   $ra, 0($sp)
    sw   $a0, 4($sp)
    sw   $a1, 8($sp)
    sw   $s0, 12($sp) # changed
    sw   $s1, 16($sp)
    sw   $s2, 20($sp) # solution
    sw   $s3, 24($sp)
    li $s0, 0
    li $s2, 1
    move $s1, $a0
quant_solve_first_do_while:
    jal  rule1
    move $s0, $v0
    beq  $s0, $zero, quant_solve_first_if
    move $a0, $s1
    jal  board_done
    beq  $v0, $zero, quant_solve_first_do_while
quant_solve_first_if:
    move $a0, $s1
    jal  board_done
    bne  $v0, $zero, quant_solve_second_if
    addi $s2, $s2, 1
quant_solve_second_do_while:
    move $a0, $s1
    jal  rule1
    move $s0, $v0
    move $a0, $s1
    jal  rule2
    or   $s0, $s0, $v0
    beq  $s0, $zero, quant_solve_second_if
    move $a0, $s1
    jal  board_done
    bne  $v0, $zero, quant_solve_second_do_while
quant_solve_second_if:
    move $a0, $s1
    jal  board_done
    li   $v0, 0
    beq  $v0, $zero, quant_solve_exit
    move $v0, $s2
quant_solve_exit:
    lw   $ra, 0($sp)
    lw   $a0, 4($sp)
    lw   $a1, 8($sp)
    lw   $s0, 12($sp) # changed
    lw   $s1, 16($sp) # iter
    lw   $s2, 20($sp) # solution
    lw   $s3, 24($sp)
    add  $sp, $sp, 28
    jr   $ra

        .align    2
        .globl board_done
# BOARD_DONE
board_done:
    sub  $sp, $sp, 24
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # i
    sw   $s1, 8($sp)     # j
    sw   $s2, 12($sp)    # GRID_SIZE
    sw   $s3, 16($sp)    # arg
    sw   $a0, 20($sp)
    and  $s0, $zero, $s0
    and  $s1, $zero, $s1
    li   $s2, GRID_SQUARED
    move $s3, $a0
board_done_outer_loop:  # for (int i = 0 ; i < GRID_SQUARED ; ++ i)
    bge  $s0, $s2, board_done_exit
    li   $s1, 0
board_done_inner_loop:  # for (int j = 0 ; j < GRID_SQUARED ; ++ j)
    bge  $s1, $s2, board_done2_exit
    mul  $t0, $s0, GRID_SQUARED    # i * 16
    add  $t0, $t0, $s1   # i * GRID_SQUARED + j
    mul  $t0, $t0, 0x0002     # (i * GRID_SQUARED + j) * data_size
    add  $t0, $t0, $s3   # &board[i][j]
    lhu  $a0, 0($t0)
    jal  has_single_bit_set
    bne  $v0, $zero, board_done_not_if #if (!has_single_bit_set(board[i][j]))
    move $v0, $zero     # return false;
    j    board_done_finish
board_done_not_if:
    addi  $s1, $s1, 1
    j    board_done_inner_loop
board_done2_exit:
    addi  $s0, $s0, 1
    j    board_done_outer_loop
board_done_exit:
    li   $v0, 1 # return true;
board_done_finish:
    lw   $a0, 20($sp)
    lw   $s3, 16($sp)
    lw   $s2, 12($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $ra, 0($sp)
    add  $sp, $sp, 24
    jr $ra
# BOARD_DONE
# PRINT BOARD
print_board:
    sub  $sp, $sp, 20
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    move $s0, $a0
    li   $s1, 0          # $s1 is i
pb_for_i:
    bge  $s1, GRID_SQUARED, pb_done_for_i
    li   $s2, 0          # $s2 is j
pb_for_j:
    bge  $s2, GRID_SQUARED, pb_done_for_j
    mul  $t0, $s1, GRID_SQUARED    # i * 16
    add  $t0, $t0, $s2   # i * 16 + j
    mul  $t0, $t0, 0x0002     # (i * 16 + j) * data_size
    add  $t0, $t0, $s0   # &board[i][j]
    lhu  $s3, 0($t0)     # value = board[i][j]

    move $a0, $s3
    jal  has_single_bit_set
    li   $a0, '*'        # c = '*'
    beq  $v0, $0, pb_skip_if # if (has_single_bit_set(value))
    move $a0, $s3
    jal  get_lowest_set_bit  # get_lowest_bit_set(value)
    add  $t0, $v0, 1         # c
    la   $t1, symbollist
    add  $t0, $t0, $t1
    lbu  $a0, 0($t0)
pb_skip_if:
    li   $v0, 11  #printf(c)
    syscall
    add  $s2, $s2, 1
    j    pb_for_j
pb_done_for_j:
    li   $a0, '\n'
    li   $v0, 11   #printf("\n")
    syscall
    add  $s1, $s1, 1
    j    pb_for_i
pb_done_for_i:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    add  $sp, $sp, 20
    
    jr   $ra
# PRINT BOARD
# HAS SINGLE BIT SET
has_single_bit_set:
    bne  $a0, $0, skip_hs_if_1
    li   $v0, 0
    jr   $ra
skip_hs_if_1:
    sub  $t0, $a0, 1
    and  $t0, $a0, $t0
    beq  $t0, $0, skip_hs_if2
    li   $v0, 0
    jr   $ra
skip_hs_if2:
    li   $v0, 1
    jr   $ra
# HAS SINGLE BIT SET
# GET LOWEST SET BIT
get_lowest_set_bit:
    li   $t0, 0
    li   $t1, 16
    li   $t2, 1
gl_for:
    bge  $t0, $t1, done_gl_loop
    and  $t3, $a0, $t2
    beq  $t3, $0, skip_gl_if
    move $v0, $t0
    jr   $ra
skip_gl_if:
    sll  $t2, $t2, 1
    add  $t0, $t0, 1
    j    gl_for
done_gl_loop:
    li   $v0, 0
    jr   $ra
# GET LOWEST SET BIT
# QUANT_SOLVE
# QUANT_SOLVE
# RULE 1
rule1:
    sub  $sp, $sp, 0x0020
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # board
    sw   $s1, 8($sp)     # changed
    sw   $s2, 12($sp)    # i
    sw   $s3, 16($sp)    # j
    sw   $s4, 20($sp)    # ii
    sw   $s5, 24($sp)    # value
    sw   $a0, 28($sp)    # saved a0
    move $s0, $a0
    li   $s1, 0          # $s1 is changed
    li   $s2, 0
r1_for_i:
    bge  $s2, GRID_SQUARED, r1_done_for_i
    li   $s3, 0
r1_for_j:
    bge  $s3, GRID_SQUARED, r1_done_for_j
    mul  $t0, $s2, GRID_SQUARED   # i * 16
    add  $t0, $t0, $s3   # i * 16 + j
    mul  $t0, $t0, 0x0002     # (i * 16 + j) * data_size
    add  $t0, $t0, $s0   # &board[i][j]
    lhu  $s5, 0($t0)     # board[i][j]
    move $a0, $s5
    jal  has_single_bit_set
    beq  $v0, $0, r1_inc_j
    li   $t1, 0          # k
r1_for_k:
    bge  $t1, GRID_SQUARED, r1_done_for_k
    beq  $t1, $s3, r1_skip_inner_if1
    mul  $t0, $s2, GRID_SQUARED    # i * 16
    add  $t0, $t0, $t1   # i * 16 + k
    mul  $t0, $t0, 0x0002     # (i * 16 + k) * data_size
    add  $t0, $t0, $s0   # &board[i][k]
    lhu  $t2, 0($t0)     # board[i][k]
    and  $t3, $s5, $t2   # board[i][k] & value
    beq  $t3, $0, r1_skip_inner_if1
    not  $t4, $s5        # ~value
    and  $t3, $t4, $t2   # 
    sh   $t3, 0($t0)     # board[i][k] = 
    li   $s1, 1
r1_skip_inner_if1:
    beq  $t1, $s2, r1_skip_inner_if2
    mul  $t0, $t1, GRID_SQUARED    # k * 16
    add  $t0, $t0, $s3   # k * 16 + j
    mul  $t0, $t0, 0x0002     # (k * 16 + j) * data_size
    add  $t0, $t0, $s0   # &board[k][j]
    lhu  $t2, 0($t0)     # board[k][j]
    and  $t3, $s5, $t2   # board[k][j] & value
    beq  $t3, $0, r1_skip_inner_if2
    not  $t4, $s5        # ~value
    and  $t3, $t4, $t2   # 
    sh   $t3, 0($t0)     # board[i][k] = 
    li   $s1, 1
r1_skip_inner_if2:
    
    add  $t1, $t1, 1
    j    r1_for_k
r1_done_for_k:
    move $a0, $s2
    jal  get_square_begin
    move $s4, $v0       # ii = get_square_begin(i)
    move $a0, $s3
    jal  get_square_begin
                        # jj = get_square_begin(j)
    move $t8, $s4       # k = ii
    add  $t5, $s4, 0x0004    # ii + GRIDSIZE
r1_for_k2:
    bge  $t8, $t5, r1_done_for_k2
    move $t9, $v0       # l = jj
    add  $t6, $v0, 0x0004    # jj + GRIDSIZE
r1_for_l:
    bge  $t9, $t6, r1_done_for_l
    bne  $t8, $s2, r1_skip_inner_if3
    bne  $t9, $s3, r1_skip_inner_if3
    j    r1_skip_inner_if4
r1_skip_inner_if3:
    mul  $t0, $t8, GRID_SQUARED    # k * 16
    add  $t0, $t0, $t9   # k * 16 + l
    mul  $t0, $t0, 0x0002     # (k * 16 + l) * data_size
    add  $t0, $t0, $s0   # &board[k][l]
    lhu  $t2, 0($t0)     # board[k][l]
    and  $t3, $s5, $t2   # board[k][l] & value
    beq  $t3, $0, r1_skip_inner_if4
    not  $t4, $s5        # ~value
    and  $t3, $t4, $t2   # 
    sh   $t3, 0($t0)     # board[i][k] = 
    li   $s1, 1
r1_skip_inner_if4:   
    add  $t9, $t9, 1
    j    r1_for_l
r1_done_for_l:
    add  $t8, $t8, 1
    j    r1_for_k2
r1_done_for_k2:
    nop
r1_inc_j:
    add  $s3, $s3, 1
    j    r1_for_j
r1_done_for_j:
    add  $s2, $s2, 1
    j    r1_for_i
r1_done_for_i:
    move $v0, $s1          # return changed
r1_return:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    lw   $a0, 28($sp)    # saved a0
    add  $sp, $sp, 0x0020
    jr   $ra
# RULE 1
# RULE 2
rule2:
    sub  $sp, $sp, 36
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)     # board
    sw   $s1, 8($sp)     # changed
    sw   $s2, 12($sp)    # i
    sw   $s3, 16($sp)    # j
    sw   $s4, 20($sp)    # ii
    sw   $s5, 24($sp)    # value
    sw   $a0, 28($sp)    # saved a0
    sw   $s6, 0x0020($sp)    # &board[i][j]
    move $s0, $a0
    li   $s1, 0          # $s1 is changed
    li   $s2, 0
r2_for_i:
    bge  $s2, GRID_SQUARED, r2_done_for_i
    li   $s3, 0
r2_for_j:
    bge  $s3, GRID_SQUARED, r2_done_for_j
    mul  $t0, $s2, GRID_SQUARED   # i * 16
    add  $t0, $t0, $s3   # i * 16 + j
    mul  $t0, $t0, 0x0002     # (i * 16 + j) * data_size
    add  $t0, $t0, $s0   # &board[i][j]
    move $s6, $t0        # save &board[i][j]
    lhu  $s5, 0($t0)     # board[i][j]
    move $a0, $s5
    jal  has_single_bit_set
    bne  $v0, $0, r2_inc_j


##################
### first k loop #
##################
    li   $t8, 0         # jsum = 0
    li   $t9, 0         # isum = 0
    
    li   $t1, 0          # k
r2_for_k:
    bge  $t1, GRID_SQUARED, r2_done_for_k
    beq  $t1, $s3, r2_skip_inner_k_if1
    mul  $t0, $s2, GRID_SQUARED    # i * 16
    add  $t0, $t0, $t1   # i * 16 + k
    mul  $t0, $t0, 0x0002     # (i * 16 + k) * data_size
    add  $t0, $t0, $s0   # &board[i][k]
    lhu  $t2, 0($t0)     # board[i][k]
    or   $t8, $t2, $t8   # jsum |= board[i][k]
r2_skip_inner_k_if1:
    beq  $t1, $s2, r2_skip_inner_k_if2
    mul  $t0, $t1, GRID_SQUARED    # k * 16
    add  $t0, $t0, $s3   # k * 16 + j
    mul  $t0, $t0, 0x0002     # (k * 16 + j) * data_size
    add  $t0, $t0, $s0   # &board[k][j]
    lhu  $t2, 0($t0)     # board[k][j]
    or   $t9, $t2, $t9   # isum |= board[k][j]
r2_skip_inner_k_if2:
    add  $t1, $t1, 1
    j    r2_for_k
r2_done_for_k:


### if_else-if structure
    beq  $t8, ALL_VALUES, r2_skip_to_else_if
    not  $t2, $t8        # ~jsum
    and  $t2, $t2, ALL_VALUES
    sh   $t2, 0($s6)     # board[i][j] = &
    li   $s1, 1
    j    r2_inc_j
r2_skip_to_else_if:
    beq  $t9, ALL_VALUES, r2_get_square_begin
    not  $t2, $t9        # ~isum
    and  $t2, $t2, ALL_VALUES
    sh   $t2, 0($s6)     # board[i][j] = &
    li   $s1, 1
    j    r2_inc_j


r2_get_square_begin:
    move $a0, $s2
    jal  get_square_begin
    move $s4, $v0       # ii = get_square_begin(i)
    move $a0, $s3
    jal  get_square_begin
                        # jj = get_square_begin(j)
                        
    li   $t7, 0         # sum = 0
    move $t8, $s4       # k = ii
    add  $t5, $s4, 0x0004    # ii + GRIDSIZE
r2_for_k2:
    bge  $t8, $t5, r2_done_for_k2
    move $t9, $v0       # l = jj
    add  $t6, $v0, 0x0004    # jj + GRIDSIZE
r2_for_l:
    bge  $t9, $t6, r2_done_for_l
    bne  $t8, $s2, r2_skip_inner_if3
    bne  $t9, $s3, r2_skip_inner_if3
    j    r2_skip_inner_if4
r2_skip_inner_if3:
    mul  $t0, $t8, GRID_SQUARED    # k * 16
    add  $t0, $t0, $t9   # k * 16 + l
    mul  $t0, $t0, 0x0002     # (k * 16 + l) * data_size
    add  $t0, $t0, $s0   # &board[k][l]
    lhu  $t2, 0($t0)     # board[k][l]
    or   $t7, $t2, $t7

r2_skip_inner_if4:   
    add  $t9, $t9, 1
    j    r2_for_l
r2_done_for_l:
    add  $t8, $t8, 1
    j    r2_for_k2
r2_done_for_k2:

    beq  $t7, ALL_VALUES, r2_inc_j
    not  $t2, $t7        # ~sum
    and  $t2, $t2, ALL_VALUES
    sh   $t2, 0($s6)     # board[i][j] = &
    li   $s1, 1
    
r2_inc_j:
    add  $s3, $s3, 1
    j    r2_for_j
r2_done_for_j:
    add  $s2, $s2, 1
    j    r2_for_i
r2_done_for_i:
    move $v0, $s1          # return changed
r2_return:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    lw   $a0, 28($sp)    # saved a0
    lw   $s6, 0x0020($sp)    # &board[i][j]
    add  $sp, $sp, 36
    jr   $ra
# RULE 2
# GET_SQUARE_BEGIN
get_square_begin:
    div $v0, $a0, GRIDSIZE
    mul $v0, $v0, GRIDSIZE
    jr  $ra
# GET_SQUARE_BEGIN

        .align    2
        .globl    main

# Comment: this adversary.s is created by multiple coder over different semesters, and it is kind of over complicated. 
# There is no need to follow this bot's format, but you can take some of its functions for reference if you want.

main:

                 
        addiu     $sp,$sp,-64
        sw        $ra,60($sp)
        sw        $s7,56($sp)
        sw        $s6,52($sp)
        sw        $s5,48($sp)
        sw        $s4,44($sp)
        sw        $s3,40($sp)
        sw        $s2,36($sp)
        sw        $s1,32($sp)
        sw        $s0,28($sp)

        # Construct interrupt mask
        li        $t4, 0
        or        $t4, $t4, TIMER_INT_MASK # enable timer interrupt
        or        $t4, $t4, BONK_INT_MASK # enable bonk interrupt
        or        $t4, $t4, REQUEST_PUZZLE_INT_MASK # enable puzzle interrupt
        or        $t4, $t4, RESPAWN_INT_MASK # enable respawn interrupt
        or        $t4, $t4, 1           # global enable
        mtc0      $t4, $t4
        


        li        $v0,10                 # 0xa
        sw        $v0, VELOCITY
        li        $t1, 180
        sw        $t1, ANGLE
        li        $t1, 1
        sw        $t1, ANGLE_CONTROL

        

        la        $s0, board
        sw        $s0, REQUEST_PUZZLE
        la        $s1, board
        la        $s5,interrupt_struct
        la        $s7,rng_state
        la        $s3,shot_charging
        move      $s4,$s1
        move      $s2,$s0
        li        $s6,10                # 0xa
$L138:            
        lbu       $v1,2($s5)
        andi      $v1,$v1,0x00ff
        beq       $v1,$0,$L135
        move      $a1,$s4
        move      $a0,$s2
        sb        $0,2($s5)
        jal       quant_solve
        sw        $s1, SUBMIT_SOLUTION
        sw        $s0, REQUEST_PUZZLE
        li        $v1,1                  # 0x1
$L135:            
        lbu       $v0,0($s5)
        andi      $v0,$v0,0x00ff
        beq       $v0,$0,$L136
        lw        $v0,0($s7)
        sll       $a0,$v0,13
        xor       $v0,$v0,$a0
        srl       $a0,$v0,17
        xor       $v0,$v0,$a0
        sll       $a0,$v0,5
        xor       $v0,$v0,$a0
        divu      $0,$v0,$s6
        sw        $v0,0($s7)
        mfhi      $v0
        sw        $v0, VELOCITY

        sb        $0,0($s5)
$L136:            
        lbu       $v0,3($s5)
        andi      $v0,$v0,0x00ff
        beq       $v0,$0,$L137
        lw        $v0,0($s7)
        sll       $a0,$v0,13
        xor       $v0,$v0,$a0
        srl       $a0,$v0,17
        xor       $v0,$v0,$a0
        sll       $a0,$v0,5
        xor       $v0,$v0,$a0
        divu      $0,$v0,$s6
        sw        $v0,0($s7)
        mfhi      $v0
        sw        $v0, VELOCITY

        sb        $0,3($s5)
$L137:            
        beq       $v1,$0,$L138
        lw        $v0,0($s7)
        lbu       $a1,0($s3)
        sll       $a0,$v0,13
        xor       $v0,$a0,$v0
        srl       $a0,$v0,17
        xor       $a0,$a0,$v0
        sll       $v0,$a0,5
        xor       $v0,$v0,$a0
        sll       $v1,$v0,13
        xor       $v0,$v1,$v0
        srl       $v1,$v0,17
        xor       $v1,$v1,$v0
        sll       $v0,$v1,5
        andi      $a0,$a0,0x3
        xor       $v1,$v0,$v1
        beq       $a1,$0,$L139
        andi      $a1,$v1,0x3
        beq       $a0,$0,$L140
        sll       $v0,$v1,13
        xor       $v0,$v0,$v1
        srl       $v1,$v0,17
        xor       $v1,$v1,$v0
        sll       $v0,$v1,5
        xor       $v1,$v0,$v1
        move      $a0,$a1
$L139:            
        sw        $a0, CHARGE_SHOT
        li        $v0,1                  # 0x1
        sb        $v0,0($s3)
$L141:            
        li        $v0,360                # 0x168
        divu      $0,$v1,$v0
        mfhi      $v0
        sw        $v0, ANGLE
        li        $v0, 1
        sw        $v0, ANGLE_CONTROL

        sll       $v0,$v1,13
        xor       $v0,$v0,$v1
        srl       $v1,$v0,17
        xor       $v0,$v0,$v1
        sll       $v1,$v0,5
        xor       $v0,$v0,$v1
        divu      $0,$v0,$s6
        sw        $v0,0($s7)
        mfhi      $v0
        sw        $v0, VELOCITY

        b         $L138
$L140:            
        sw        $a1, SHOOT
        sll       $v0,$v1,13
        xor       $v0,$v0,$v1
        srl       $v1,$v0,17
        xor       $v1,$v1,$v0
        sll       $v0,$v1,5
        sb        $0,0($s3)
        xor       $v1,$v0,$v1
        b         $L141
        .globl    rng_state
.data             
        .align    2
rng_state:        
        .word     255
        .globl    shot_charging
shot_charging:    
        .byte     1
        .globl    game_map
        .align    2
game_map:         
        .ascii    "\001\000"
        .space    38
        .space    1560
        .globl    op_bullets
        .align    2
op_bullets:       
        .word     1
        .space    32
        .globl    my_bullets
        .align    2
my_bullets:       
        .word     1
        .space    32
        .globl    bot_scores
        .align    2
bot_scores:       
        .word     1
        .space    4
        # .globl    puzzle_solution
        # .align    2
# puzzle_solution:  
#         .space    4
#         .word     puzzle_solution+8
#         .space    48
#         .globl    puzzle_request_dest
# .data             
#         .align    2
# puzzle_request_dest: 
#         .word     1
#         .space    12
#         .space    312
.kdata
chunkIH:    .space 40
ih_rng_state: .word 255
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt


interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    and     $a0, $k0, RESPAWN_INT_MASK
    bne     $a0, 0, respawn_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    li      $a0,1
    sb      $a0,interrupt_struct
      # [NOTE: This is an inline call to rng()]
    lw    $v0,ih_rng_state
    sll   $a0,$v0,13
    xor   $a0,$a0,$v0
    srl   $v0,$a0,17
    xor   $a0,$v0,$a0
    sll   $v0,$a0,5
    xor   $v0,$v0,$a0
    sw    $v0,ih_rng_state
    li    $a0, 360
    div   $v0, $a0
    mfhi  $v0
    bgez  $v0, $positive_angle
    addu  $v0, $v0, 360
$positive_angle:
    sw    $v0, ANGLE
    sw    $0,  ANGLE_CONTROL
    li    $a0, 10
    sw    $a0, VELOCITY
    bge   $v0, 278, branch_no_shoot
    ble	  $v0, 262, branch_no_shoot
    
    li    $t0, 0
    sw    $t0, SHOOT
branch_no_shoot:
    sb    $a0, interrupt_struct
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    li      $a0,1
    sb      $a0,interrupt_struct+1
    #Fill in your timer handler code here
    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    li      $a0,1
    sb      $a0,interrupt_struct+2
    #Fill in your puzzle interrupt code here
    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK
    li      $a0,1
    sb      $a0,interrupt_struct+3
    #Fill in your respawn handler code here
    j       interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret
