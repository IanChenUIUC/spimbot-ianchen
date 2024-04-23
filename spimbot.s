SIZE                    = 40
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

OTHER_X                 = 0xffff00a0
OTHER_Y                 = 0xffff00a4

TIMER                   = 0xffff001c
GET_MAP                 = 0xffff2008

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

RESPAWN_INT_MASK        = 0x2000      ## Respawn
RESPAWN_ACK             = 0xffff00f0  ## Respawn

SHOOT                   = 0xffff2000
CHARGE_SHOT             = 0xffff2004

GET_OP_BULLETS          = 0xffff200c
GET_MY_BULLETS          = 0xffff2010
GET_AVAILABLE_BULLETS   = 0xffff2014

MMIO_STATUS             = 0xffff204c

.data
map:        .space  1600
board:      .space  512
bot_side:   .byte   0
path_done:  .byte   1

path_pos:   .word   0   # current position in the path  


ERR_STRING: .asciiz    "ERROR ERROR CRASHING AND BURNING"

.text
main:
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, RESPAWN_INT_MASK          # enable puzzle interrupt
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12

    # set which side the bot is on
    la      $t0     BOT_X
    lw      $t0     0($t0)
    li      $t1     100
    slt     $t0     $t1     $t0
    sb      $t0     bot_side

    # store the map
    la      $t0     map
    add     $t1     $0      GET_MAP
    sw      $t0     0($t1)

    # reload some bullets (SKIP)
    li      $a0     1
    jal     solve_puzzle

loop: 
 
loop_do_chase:
    lb      $t0     path_done
    beq     $t0     $0  loop_done
    sb      $0      path_done

    jal     chase_bot

loop_done:
    # lw      $t0     GET_AVAILABLE_BULLETS
    # bge     $t0     40   loop

    li      $a0     1
    jal     solve_puzzle
    j       loop

# a0 stores the counter
solve_puzzle:
    sub     $sp     $sp     8
    sw      $ra     0($sp)
    sw      $s0     4($sp)
    move    $s0     $a0

solve_puzzle_loop:
    ble     $s0     $0      solve_puzzle_end

    la      $a0     board                       # request puzzle
    sw      $a0     REQUEST_PUZZLE    
    jal     quant_solve
    la      $a0     board
    sw      $a0     SUBMIT_SOLUTION

    sub     $s0     $s0     1
    j       solve_puzzle_loop

solve_puzzle_end:
    lw      $ra     0($sp)
    lw      $s0     4($sp)    
    add     $sp     $sp     8
    jr      $ra

# sets the path
# starts the bot to chase with interrupt request
chase_bot:
    sub     $sp     $sp     4
    sw      $ra     0($sp)

    jal     get_other_pos
    move    $a0     $v0   
    jal     pathfind_init

    jal     get_bot_pos
    la      $a0     map   
    move    $a1     $v0
    jal     get_other_pos
    move    $a2     $v0   
    jal     pathfind  

    la      $t0     path
    mul     $v0     $v0     4
    add     $t0     $t0     $v0
    sw      $t0     path_pos

    lw      $t0     TIMER               # start the bot chasing  
    add     $t0     $t0     500
    sw      $t0     TIMER    

    lw      $ra     0($sp)
    add     $sp     $sp     4
    jr      $ra

# v0 stores the pos
get_bot_pos:
    la      $t0     BOT_Y
    lw      $t0     0($t0)
    div     $t0     $t0     8
    mul     $t0     $t0     SIZE
    la      $t1     BOT_X
    lw      $t1     0($t1)
    div     $t1     $t1     8
    add     $v0     $t0     $t1
    jr      $ra

# v0 stores the pos
get_other_pos:
    la      $t0     OTHER_Y
    lw      $t0     0($t0)
    mul     $t0     $t0     SIZE
    la      $t1     OTHER_X
    lw      $t1     0($t1)
    add     $v0     $t0     $t1
    jr      $ra

.kdata
chunkIH:            .space 40
non_intrpt_str:     .asciiz "Non-interrupt exception\n"
unhandled_str:      .asciiz "Unhandled interrupt type\n"
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
    #Fill in your bonk handler code here
    j       interrupt_dispatch      # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK

    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK

    j       interrupt_dispatch

timer_interrupt:
    sw      $0      TIMER_ACK

    sw      $0      VELOCITY        # set velocity to 0

    la      $t0     path_pos
    la      $t1     path

    lw      $t2     0($t0)          # path is done
    ble     $t2     $t1      end_timer   

    sub     $t2     $t2     4       # move onto next pos in path  
    sw      $t2     0($t0)

    la      $t0     path_pos
    lw      $t0     0($t0)    

    lw      $a0     4($t0)          # cur
    lw      $a1     0($t0)          # next
    move    $t5     $ra
    jal     do_move
    move    $ra     $t5

    lw      $t0     TIMER
    add     $t0     $t0     16000
    sw      $t0     TIMER     

    j       interrupt_dispatch

end_timer:
    li      $t0     1
    sb      $t0     path_done
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

# set the velocity and direction based on the path
# a0 stores current
# a1 stores next
do_move:
    sub     $sp     $sp     8
    sw      $ra     0($sp)
    sw      $s0     4($sp)
    move    $s0     $a1    

    li      $t0     5                  # velocity
    la      $t1     VELOCITY
    sw      $t0     0($t1)              # set velocity

    div     $t0     $a0     SIZE        # p.r
    rem     $t1     $a0     SIZE        # p.c
    div     $t2     $a1     SIZE        # q.r
    rem     $t3     $a1     SIZE        # q.c

    sub     $a0     $t0     $t2         # p.r - q.r
    sub     $a1     $t1     $t3         # p.c - q.c
    jal     get_angle
    move    $t2     $v0                 # angle

end_do_move:
    la      $t0     map
    sw      $t0     GET_MAP
    add     $t0     $t0     $s0         # &map[next]
    lb      $t0     0($t0)              # map[next]

    lb      $t1     bot_side
    bne     $t0     $t1     do_shoot
    j       do_set_angle

do_shoot:
    div     $t3     $t2     90          # get direction
    add     $t3     $t3     1
    rem     $t3     $t3     4
    sw      $t3     SHOOT

do_set_angle:
    la      $t3     ANGLE               # set angle
    sw      $t2     0($t3)
    la      $t3     ANGLE_CONTROL       # set abs angle
    li      $t2     1
    sw      $t2     0($t3)

return_do_move:
    lw      $ra     0($sp)
    lw      $s0     4($sp)
    add     $sp     $sp     8
    jr      $ra

# a0 is p.r - q.r
# a1 is p.c - q.c
# v0 is the angle (0, 90, 180, 270)
get_angle:

is_north:
    bne     $a0     1       is_south
    bne     $a1     0       is_south
    li      $v0     270
    j       end_get_angle

is_south:
    bne     $a0     -1      is_east
    bne     $a1     0       is_east
    li      $v0     90
    j       end_get_angle

is_east:
    bne     $a0     0       is_west
    bne     $a1     -1      is_west
    li      $v0     0
    j       end_get_angle

is_west:
    bne     $a0     0       direction_err
    bne     $a1     1       direction_err
    li      $v0     180
    j       end_get_angle

end_get_angle:
    jr      $ra

direction_err:
    li      $v0     PRINT_STRING
    la      $a0     ERR_STRING
    syscall

    # j       loop
    j       end_get_angle