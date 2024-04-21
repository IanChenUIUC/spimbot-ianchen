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
map:        .space 1600
board:      .space 512
has_timer:  .byte  0
has_respawn:.byte  0


ERR_STRING: .asciiz    "ERROR ERROR CRASHING AND BURNING"

.text
main:
    sb      $0      has_respawn  
    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, RESPAWN_INT_MASK          # enable puzzle interrupt
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12

    # s7 stores which side we are on
    la      $t0     BOT_X
    lw      $t0     0($t0)
    li      $t1     100
    slt     $s7     $t1     $t0

    la      $t0     map
    add     $t1     $0      GET_MAP
    sw      $t0     0($t1)

loop: 
    lb      $t0     has_respawn
    bne     $t0     $0      main

    jal     chase_bot
    j       loop

# reload until bullet count >= $a0
# a0, number of bullets to reload to
reload_bullets:
    sub     $sp     $sp     4    
    sw      $ra     0($sp)

    la      $t0     GET_AVAILABLE_BULLETS
    lw      $t0     0($t0)
    sub     $t0     $t0     $a0

    div     $a0     $t0     20
    rem     $t1     $t0     20
    slt     $t1     $0      $t1
    add     $a0     $a0     $t1
    sub     $a0     $0      $a0         # negate

    jal     solve_puzzle

    lw      $ra     0($sp)
    add     $sp     $sp     4
    jr      $ra

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

chase_bot:
    sub     $sp     $sp     8
    sw      $ra     0($sp)
    sw      $s0     4($sp)

    jal     get_other_pos
    move    $a0     $v0   
    jal     pathfind_init

    jal     get_bot_pos
    la      $a0     map   
    move    $a1     $v0
    jal     get_other_pos
    move    $a2     $v0   
    jal     pathfind  
    move    $s0     $v0

    move    $a0     $s0
    jal     reload_bullets    

    move    $a0     $s0
    jal     get_bot_pos
    move    $a1     $v0
    jal     do_path

    lw      $ra     0($sp)
    lw      $s0     4($sp)
    add     $sp     $sp     8
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

# a0 stores the length of path
# a1 stores the start
do_path:
    sub     $sp     $sp     4
    sw      $ra     0($sp)

    la      $s0     path                # start of path
    move    $s1     $s0                 # current position in path
    mul     $t0     $a0     4
    add     $s1     $s1     $t0

    lw      $t0     TIMER
    add     $t0     $t0     8000
    sw      $t0     TIMER               # request timer interrupt

    move    $s2     $a1                 # current position
    j       do_path_loop

do_path_loop:
    bge     $s0     $s1     do_path_end
    
    lb      $t0     has_timer
    beq     $t0     $0      do_path_loop    
    sb      $0      has_timer

    move    $a0     $s2
    lw      $a1     -4($s1)
    jal     do_move
    move    $s2     $v0

    sub     $s1     $s1     4
    j       do_path_loop

do_path_end:
    li      $t0     0                   # velocity
    la      $t1     VELOCITY
    sw      $t0     0($t1)              # set velocity

    lw      $ra     0($sp)    
    add     $sp     $sp     4
    jr      $ra

# set the velocity and direction based on the path
# request a timer interrupt to stop move
# a0 stores current
# a1 stores next
# returns the next position (a1)
do_move:
    li      $t0     10                  # velocity
    la      $t1     VELOCITY
    sw      $t0     0($t1)              # set velocity
    move    $v0     $a1       

    la      $t1     TIMER
    lw      $t0     0($t1)
    add     $t0     $t0     8000
    sw      $t0     0($t1)              # request timer interrupt

    div     $t0     $a0     SIZE        # p.r
    rem     $t1     $a0     SIZE        # p.c
    div     $t2     $a1     SIZE        # q.r
    rem     $t3     $a1     SIZE        # q.c

    sub     $t0     $t0     $t2         # p.r - q.r
    sub     $t1     $t1     $t3         # p.c - q.c

    # reserve t2 for the angle

is_north:
    bne     $t0     1       is_south
    bne     $t1     0       is_south
    li      $t2     270
    j       end_do_move

is_south:
    bne     $t0     -1      is_east
    bne     $t1     0       is_east
    li      $t2     90
    j       end_do_move

is_east:
    bne     $t0     0       is_west
    bne     $t1     -1      is_west
    li      $t2     0
    j       end_do_move

is_west:
    bne     $t0     0       direction_err
    bne     $t1     1       direction_err
    li      $t2     180
    j       end_do_move

end_do_move:
    la      $t0     map  
    add     $t0     $t0     $a1         # &map[next]
    lb      $t0     0($t0)              # map[next]

    bne     $t0     $s7     do_shoot
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

    jr      $ra

direction_err:
    li      $v0     PRINT_STRING
    la      $a0     ERR_STRING
    syscall

    j       loop

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

timer_interrupt:
    sw      $0, TIMER_ACK

    li      $t0     1
    la      $t1     has_timer
    sb      $t0     0($t1)

    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK

    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK

    li      $t0     1
    la      $t1     has_respawn
    sb      $t0     0($t1)

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