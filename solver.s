sudoku_solve:
    sub $sp, $sp, 120
    sw $s0, 96($sp)
    sw $s1, 100($sp)
    sw $s2, 104($sp)
    sw $s3, 108($sp)
    sw $s4, 112($sp)
    sw $ra, 116($sp)

    #preprocessing
    add $s4, $sp, 64

    add $t0, $sp, 32
    li $t2, -1

    sw $t2, 0($t0)
    sw $t2, 4($t0)
    sw $t2, 8($t0)
    sw $t2, 12($t0)
    sw $t2, 16($t0)
    sw $t2, 20($t0)
    sw $t2, 24($t0)
    sw $t2, 28($t0)
    sw $t2, 32($t0)
    sw $t2, 36($t0)
    sw $t2, 40($t0)
    sw $t2, 44($t0)
    sw $t2, 48($t0)
    sw $t2, 52($t0)
    sw $t2, 56($t0)
    sw $t2, 60($t0)

    sudoku_prefill_end:
    li $t7, 256
    move $t6, $a0
    li $t0, 0
    move $s1, $sp
    sudoku_for_i:
        bge $t0, 16, sudoku_for_i_end
        li $t1, 0
        add $s0, $sp, 32
        li $s2, 0xffff

        sudoku_for_j:
            bge $t1, 16, sudoku_for_j_end
            lhu $t2, 0($t6)      #$t2 = board[i][j]
            sub $t3, $0, $t2
            and $t3, $t2, $t3
            bne $t2, $t3, sudoku_ambiguous
                sub $t7, $t7, 1

                lhu $t4, 0($s0)
                xor $t4, $t4, $t2
                sh $t4, 0($s0)

                xor $s2, $s2, $t2

                and $t3, $t0, 12
                srl $t4, $t1, 2
                add $t3, $t3, $t4
                sll $t3, $t3, 1
                add $t3, $t3, $s4
                lhu $t4, 0($t3)
                xor $t4, $t4, $t2
                sh $t4, 0($t3)

            sudoku_ambiguous:

            add $t1, $t1, 1
            add $t6, $t6, 2
            add $s0, $s0, 2
            j sudoku_for_j
            sudoku_for_j_end:
        sh $s2, 0($s1)
        add $s1, $s1, 2
        add $t0, $t0, 1
        j sudoku_for_i
    sudoku_for_i_end:
    
    sudoku_while_unsolved:
        ble $t7, 0, sudoku_solved
        add $a1, $sp, 64
        add $a3, $sp, 32
        move $s4, $a0
        move $v0, $a1

        move $s0, $sp
        sudoku_for_x:
            bge $s0, $a3, sudoku_while_unsolved
            add $s1, $s0, 8
            move $s2, $a3
            sudoku_for_y:
                bge $s2, $v0, sudoku_for_y_end
                add $s3, $s2, 8

                lhu $t4, 0($a1)
                beq $t4, 0, sudoku_unroll_next
                    jal sudoku_unroll
                    sh $t4, 0($a1)
                sudoku_unroll_next:
                add $s2, $s2, 8
                add $s4, $s4, 8
                add $a1, $a1, 2
                j sudoku_for_y
            sudoku_for_y_end:
            add $s0, $s0, 8
            add $s4, $s4, 96
            j sudoku_for_x  
    sudoku_solved:

    lw $s0, 96($sp)
    lw $s1, 100($sp)
    lw $s2, 104($sp)
    lw $s3, 108($sp)
    lw $s4, 112($sp)
    lw $ra, 116($sp)
    add $sp, $sp, 120
    jr $ra


    sudoku_unroll:
        move $t0, $s0
        move $a2, $s4
        sudoku_for_i0:
            bge $t0, $s1, sudoku_for_i0_end
            move $t1, $s2
            lhu $t5, 0($t0)
            sudoku_for_j0:
                bge $t1, $s3, sudoku_for_j0_end
            
                lhu $t2, 0($a2)
                sub $t3, $0, $t2
                and $t3, $t3, $t2
                beq $t3, $t2, sudoku_solved0
                    
                    lhu $t6, 0($t1)

                    and $t2, $t2, $t4
                    and $t2, $t2, $t5
                    and $t2, $t2, $t6

                    sub $t3, $0, $t2
                    and $t3, $t3, $t2

                    bne $t3, $t2, sudoku_solved0
                        sub $t7, $t7, 1
                        xor $t4, $t4, $t2
                        xor $t5, $t5, $t2
                        xor $t6, $t6, $t2
                        sh $t6, 0($t1)
                        sh $t2, 0($a2)

                sudoku_solved0:
                add $t1, $t1, 2
                add $a2, $a2, 2
                j sudoku_for_j0
            sudoku_for_j0_end:

            sh $t5, 0($t0)
            add $t0, $t0, 2
            add $a2, $a2, 24
            j sudoku_for_i0
        sudoku_for_i0_end:
    sudoku_unroll_end:
        jr $ra