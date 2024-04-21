GRIDSIZE = 4
GRID_SQUARED = 16
ALL_VALUES = 65535
.data
symbollist:
  .byte '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' 'A' 'B' 'C' 'D' 'E' 'F' 'G'

# Below are the provided puzzle functionality.
.text
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