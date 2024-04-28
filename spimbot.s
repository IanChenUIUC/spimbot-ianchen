MAP_SIZE                = 40
TILE_SIZE               = 8
HALF_TILE_SIZE          = 4
MAX_PATH_LEN            = 4


# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

RESPAWN_INT_MASK        = 0x2000      ## Respawn
RESPAWN_ACK             = 0xffff00f0  ## Respawn

MMIO_STATUS             = 0xffff204c
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

SHOOT                   = 0xffff2000
CHARGE_SHOT             = 0xffff2004

GET_OP_BULLETS          = 0xffff200c
GET_MY_BULLETS          = 0xffff2010
GET_AVAILABLE_BULLETS   = 0xffff2014

.data
map:        .space  1600
board:      .space  512
bot_side:   .byte   0
path_done:  .byte   1
has_puzzle: .byte   0

path_pos:   .word   0   # current position in the path  
path_end:   .word   0   # end of path (beginning) 

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
    lw      $t0     BOT_X
    li      $t1     100
    slt     $t0     $t1     $t0
    sb      $t0     bot_side

    # store the map
    la      $t0     map
    sw      $t0     GET_MAP

    jal     request_puzzle

loop: 
 
loop_solve_puzzle:
    lb      $t0     has_puzzle
    beq     $t0     $0  loop_do_chase
    sb      $0      has_puzzle

    jal     solve_puzzle
    jal     request_puzzle

loop_do_chase:
    lb      $t0     path_done
    beq     $t0     $0  loop_end
    sb      $0      path_done

    jal     chase_bot

loop_end:
    j       loop

# requests a puzzle :)
# no arguments
request_puzzle:
    la      $t0     board                       # request puzzle
    sw      $t0     REQUEST_PUZZLE    
    jr      $ra

# requires a puzzle to be successfully requested
# no arguments
solve_puzzle:
    sub     $sp     $sp     4
    sw      $ra     0($sp)

    la      $a0     board
    jal     sudoku_solve
    la      $a0     board
    sw      $a0     SUBMIT_SOLUTION

    lw      $ra     0($sp)
    add     $sp     $sp     4
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

set_path_pos:
    la      $t0     path
    mul     $v0     $v0     4
    add     $t0     $t0     $v0
    sw      $t0     path_pos

    bge     $v0     MAX_PATH_LEN    set_path_pos_cutoff

    la      $t0     path
    sw      $t0     path_end 
    j       start_bot_chase   

set_path_pos_cutoff:
    lw      $t0     path_pos
    li      $t1     4
    mul     $t1     $t1     MAX_PATH_LEN
    sub     $t0     $t0     $t1
    sw      $t0     path_end

start_bot_chase:
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
    div     $t0     $t0     TILE_SIZE
    mul     $t0     $t0     MAP_SIZE
    la      $t1     BOT_X
    lw      $t1     0($t1)
    div     $t1     $t1     TILE_SIZE
    add     $v0     $t0     $t1
    jr      $ra

# v0 stores the pos
get_other_pos:
    la      $t0     OTHER_Y
    lw      $t0     0($t0)
    mul     $t0     $t0     MAP_SIZE
    la      $t1     OTHER_X
    lw      $t1     0($t1)
    add     $v0     $t0     $t1
    jr      $ra

.kdata
chunkIH:            .space 40
non_intrpt_str:     .asciiz "Non-interrupt exception\n"
unhandled_str:      .asciiz "Unhandled interrupt type\n"

three:  .float  3.0
five:   .float  5.0
PI:     .float  3.141592
F180:   .float  180.0

.ktext 0x80000180

interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)             # Restore saved registers
    sw      $a1, 4($k0)             # Restore saved registers
    sw      $a2, 8($k0)             # Restore saved registers
    sw      $a3, 12($k0)            # Restore saved registers
    sw      $v0, 16($k0)
    sw      $t0, 20($k0)
    sw      $t1, 24($k0)
    sw      $t2, 28($k0)
    sw      $t3, 32($k0)
    sw      $t4, 36($k0)
    sw      $t5, 40($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 44($k0)
    mflo    $t0
    sw      $t0, 48($k0)

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
    j       interrupt_dispatch      # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    li      $t0 1
    sb      $t0 has_puzzle        

    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK

    la      $t0 path
    sw      $t0 path_pos    
    sw      $t0 path_end

    j       interrupt_dispatch

timer_interrupt:
    sw      $0      TIMER_ACK
    sw      $0      VELOCITY        # set velocity to 0

    lw      $t0     path_pos        
    lw      $t1     path_end
    ble     $t0     $t1      end_timer   

    sub     $t0     $t0     4       # move onto next pos in path  
    sw      $t0     path_pos

    lw      $a0     BOT_X           # cur.x
    lw      $a1     BOT_Y           # cur.y

    lw      $t0     path_pos        # next
    lw      $t0     0($t0)

    # set (a2) next.x and (a3) next.y
    rem     $a2     $t0     MAP_SIZE
    mul     $a2     $a2     TILE_SIZE       
    add     $a2     $a2     HALF_TILE_SIZE
    div     $a3     $t0     MAP_SIZE
    mul     $a3     $a3     TILE_SIZE       
    add     $a3     $a3     HALF_TILE_SIZE       

    move    $t5     $ra
    jal     do_move
    move    $ra     $t5

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
    lw      $t0, 44($k0)
    mthi    $t0
    lw      $t0, 48($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $a1, 4($k0)             # Restore saved registers
    lw      $a2, 8($k0)             # Restore saved registers
    lw      $a3, 12($k0)            # Restore saved registers
    lw      $v0, 16($k0)
    lw      $t0, 20($k0)
    lw      $t1, 24($k0)
    lw      $t2, 28($k0)
    lw      $t3, 32($k0)
    lw      $t4, 36($k0)
    lw      $t5, 40($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

# set the velocity (10) and direction based on the path
# a0 stores current x pixel
# a1 stores current y pixel
# a2 stores next x pixel
# a3 stores next y pixel
# requests timer interrupt when move is done
do_move:
    sub     $sp     $sp     16
    sw      $ra     0($sp)
    sw      $s0     4($sp)              # dx 
    sw      $s1     8($sp)              # dy
    sw      $s2     12($sp)             # next.pos

    sub     $s0     $a2     $a0         # q.x - p.x
    sub     $s1     $a3     $a1         # q.y - p.y

    div     $t1     $a2     8           # col
    div     $t2     $a3     8           # row
    mul     $t2     $t2     MAP_SIZE
    add     $s2     $t1     $t2         # next position

    li      $t0     10                  # velocity
    la      $t1     VELOCITY
    sw      $t0     0($t1)              # set velocity

    move    $a0     $s0
    move    $a1     $s1
    jal     euclidean_dist
    mul     $t0     $v0     1000        # 1000 cycles per pixel

    lw      $t1     TIMER               # request timer
    add     $t0     $t0     $t1
    sw      $t0     TIMER

    move    $a0     $s0
    move    $a1     $s1
    jal     sb_arctan                   # v0 stores angle

do_set_angle:
    sw      $v0     ANGLE
    li      $t0     1
    sw      $t0     ANGLE_CONTROL

do_try_shoot:
    la      $t0     map
    sw      $t0     GET_MAP
    add     $t0     $t0     $s2         # &map[next]
    lb      $t0     0($t0)              # map[next]

    lb      $t1     bot_side
    bne     $t0     $t1     do_shoot
    j       return_do_move

do_shoot:
    div     $t0     $v0     90          # get direction
    add     $t0     $t0     1
    rem     $t0     $t0     4
    sw      $t0     SHOOT

return_do_move:
    lw      $ra     0($sp)
    lw      $s0     4($sp)
    lw      $s1     8($sp)
    lw      $s2     12($sp)
    add     $sp     $sp     16
    jr      $ra

# -----------------------------------------------------------------------
# sb_arctan - computes the arctangent of y / x
# $a0 - x
# $a1 - y
# returns the arctangent
# -----------------------------------------------------------------------
sb_arctan:
    li      $v0, 0      # angle = 0;
    abs     $t0, $a0    # get absolute values
    abs     $t1, $a1
    ble     $t1, $t0, no_TURN_90      
    ## if (abs(y) > abs(x)) { rotate 90 degrees }
    move    $t0, $a1    # int temp = y;
    neg     $a1, $a0    # y = -x;      
    move    $a0, $t0    # x = temp;    
    li      $v0, 90     # angle = 90;  
no_TURN_90:
    bgez    $a0, pos_x      # skip if (x >= 0)
    ## if (x < 0) 
    add     $v0, $v0, 180   # angle += 180;
pos_x:
    mtc1    $a0, $f0
    mtc1    $a1, $f1
    cvt.s.w $f0, $f0        # convert from ints to floats
    cvt.s.w $f1, $f1
    div.s   $f0, $f1, $f0   # float v = (float) y / (float) x;
    mul.s   $f1, $f0, $f0   # v^^2
    mul.s   $f2, $f1, $f0   # v^^3
    l.s     $f3, three      # load 3.0
    div.s   $f3, $f2, $f3   # v^^3/3
    sub.s   $f6, $f0, $f3   # v - v^^3/3
    mul.s   $f4, $f1, $f2   # v^^5
    l.s     $f5, five       # load 5.0
    div.s   $f5, $f4, $f5   # v^^5/5
    add.s   $f6, $f6, $f5   # value = v - v^^3/3 + v^^5/5
    l.s     $f8, PI         # load PI
    div.s   $f6, $f6, $f8   # value / PI
    l.s     $f7, F180       # load 180.0
    mul.s   $f6, $f6, $f7   # 180.0 * value / PI
    cvt.w.s $f6, $f6        # convert "delta" back to integer
    mfc1    $t0, $f6
    add     $v0, $v0, $t0   # angle += delta
    jr      $ra
    
# -----------------------------------------------------------------------
# euclidean_dist - computes sqrt(x^2 + y^2)
# $a0 - x
# $a1 - y
# returns the distance
# -----------------------------------------------------------------------
euclidean_dist:
    mul     $a0, $a0, $a0   # x^2
    mul     $a1, $a1, $a1   # y^2
    add     $v0, $a0, $a1   # x^2 + y^2
    mtc1    $v0, $f0
    cvt.s.w $f0, $f0        # float(x^2 + y^2)
    sqrt.s  $f0, $f0        # sqrt(x^2 + y^2)
    cvt.w.s $f0, $f0        # int(sqrt(...))
    mfc1    $v0, $f0
    jr      $ra