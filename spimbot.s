MAP_SIZE                = 40            ## 40 x 40 map
TILE_SIZE               = 8             ## 8 x 8 tile    
HALF_TILE_SIZE          = 4             ## 8 / 2 = 4
MAX_DIST                = 16            ## manhattan dist between path endpoint and opponent
MAX_BULLETS             = 50            ## don't solve puzzles when bullets > 100
MIN_BULLETS             = 20            ## don't solve puzzles when bullets > 100
PATHFIND_BUFFER         = 12            ## start calculating next path when almost done with current path

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

path_buf:   .space  48  # PATHFIND_BUFFER positions on the path
                        # when continuously updating path
path_len:   .word   0   # storing the length of the new path 
                        # while using buffer
buf_ready:  .byte  0    # stores when the buffer is done

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
    lw      $t0     GET_AVAILABLE_BULLETS
    bge     $t0     MAX_BULLETS     loop_do_chase

    lb      $t0     has_puzzle
    beq     $t0     $0  loop_do_chase
    sb      $0      has_puzzle

    jal     solve_puzzle
    jal     request_puzzle

loop_do_chase:
    lw      $t0     GET_AVAILABLE_BULLETS
    blt     $t0     MIN_BULLETS     loop_solve_puzzle

    # check if path is done
    lb      $t0     path_done
    bne     $t0     $0  do_chase_finished

    # check if path is almost done
    # and start calculating next path if it is

    lw      $t0     path_end                    # skip if already using buffer
    la      $t1     path_buf
    beq     $t0     $t1        loop_end

    lw      $t0     path_pos
    lw      $t1     path_end
    sub     $t0     $t0     $t1                 # remaining path length (* 4)

    li      $t1     4
    mul     $t1     $t1     PATHFIND_BUFFER

    ble     $t0     $t1     do_chase_near_finished

    # check if endpoint is outdated
    # that is, the manhattan distance between end and other is >= MAX_DIST
    # requires the remaining path length to be larger than PATHFIND_BUFFER

    jal     get_other_pos                       # v0 stores other   
    div     $t0     $v0     MAP_SIZE            # other.r
    rem     $t1     $v0     MAP_SIZE            # other.c

    lw      $t2     path_end
    lw      $t2     0($t2)
    rem     $t3     $t2     MAP_SIZE            # end.c
    div     $t2     $t2     MAP_SIZE            # end.r

    sub     $t0     $t0     $t2                 # dr
    abs     $t0     $t0                         # |dr|    
    sub     $t1     $t1     $t3                 # dc
    abs     $t1     $t1                         # |dc|    
    add     $t0     $t0     $t1                 # manhattan dist

    bge     $t0     MAX_DIST    do_chase_outdated

    j       loop_end

do_chase_finished:
    # when reaches the end of the path and needs to start another

    jal     get_bot_pos
    move    $a0     $v0
    jal     chase_bot
    move    $a0     $v0
    jal     set_path_pos
    jal     start_bot_chase
    sb      $0      path_done
    
    j       loop_end

do_chase_near_finished:
    # when the bot is near the end of the path

    # copy the remaining of the path into buffer
    la      $a0     path_buf
    lw      $a1     path_end
    lw      $a2     path_pos
    jal     copy_path_to_buffer

    # set the path pos and end
    sw      $v0     path_pos
    la      $t0     path_buf
    sw      $t0     path_end

    # start finding new path
    lw      $a0     0($t0)
    jal     chase_bot

    li      $t0     1
    sb      $t0     buf_ready    

    li      $t0     100
    sw      $t0     TIMER

    j       loop_end

do_chase_outdated:
    # when the opponent has moved too far from original destination

    # copy the remainder of the path into buffer
    # exactly the next PATHFIND_BUFFER elements
    la      $a0     path_buf
    lw      $a2     path_pos
    sub     $a1     $a2     48                  # 4 * PATHFIND_BUFFER
    jal     copy_path_to_buffer

    # set the path pos and end
    sw      $v0     path_pos
    la      $t0     path_buf
    sw      $t0     path_end

    # start finding new path
    lw      $t0     path_end
    lw      $a0     0($t0)                      # goes pathfind_buffer positions ahead of path 
    jal     chase_bot

    li      $t0     1
    sb      $t0     buf_ready    

    li      $t0     100
    sw      $t0     TIMER

    j       loop_end  

loop_end:
    j       loop

# copies from path_end to path_pos
# a0 is the start of the buffer
# a1 is the path_end
# a2 is the path_pos
# v0 is the pos of the pos
copy_path_to_buffer:
    move    $v0     $a0
    bgt     $a1     $a2     copy_path_return

    lw      $t0     0($a1)
    sw      $t0     0($a0)

    add     $a0     $a0     4
    add     $a1     $a1     4
    j       copy_path_to_buffer    

copy_path_return:
    sub     $v0     $v0     4 
    jr      $ra

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
# a0 stores the start of the chase
# v0 is the length of the path
chase_bot:
    sub     $sp     $sp     8
    sw      $ra     0($sp)
    sw      $s0     4($sp)
    move    $s0     $a0    

    jal     get_other_pos
    move    $a0     $v0   
    jal     pathfind_init

    la      $a0     map   
    move    $a1     $s0
    jal     get_other_pos
    move    $a2     $v0   
    jal     pathfind  
    sw      $v0     path_len

    lw      $ra     0($sp)
    lw      $s0     4($sp)
    add     $sp     $sp     8
    jr      $ra

# a0 stores the length of the path
set_path_pos:
    la      $t0     path
    mul     $a0     $a0     4
    add     $t0     $t0     $a0
    sw      $t0     path_pos

    la      $t0     path
    sw      $t0     path_end 
    jr      $ra

# requests timer 
start_bot_chase:
    lw      $t0     TIMER               # start the bot chasing  
    add     $t0     $t0     500
    sw      $t0     TIMER    
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

.data

    .align 4
    seen:       .space 1600              # 40 * 40 bytes
    heap:       .space 6400              # 40 * 40 words
    path:       .space 6400              # 40 * 40 words
    distances:  .space 6400              # 40 * 40 words
    heuristic:  .space 6400              # 40 * 40 words
    parents:    .space 6400              # 40 * 40 words

    neighbors:  .space 16                # 4 points = 4 words

.text

# GUARANTEES: does not change temps
# a0 stores the point
# v0 returns p.r
# v1 returns p.c
get_point:
    and     $v0     $a1     0xFFFF      # p.r
    lui     $v1     0xFFFF
    and     $v1     $a1     $v1         # p.c
    srl     $v1     $v1     16    
    jr      $ra

# GUARANTEES: does not change temps
# a0 stores p.r
# a1 stores p.c
# v0 returns {p.r, p.c} (half-words)
make_point:
    sll     $a1     $a1     16
    add     $v0     $a0     $a1
    jr      $ra

# a0 stores a pointer to the map array
# a1 stores the current Point
is_walkable:
    move    $t9     $ra                 # copy $ra
    move    $t8     $a0                 # copy a0
    move    $a0     $a1    
    jal     get_point                   # a0 = p.r; a1 = p.c
    move    $ra     $t9                 # restore $ra

    blt     $v0     0           ret_f
    blt     $v1     0           ret_f
    bge     $v0     MAP_SIZE    ret_f
    bge     $v1     MAP_SIZE    ret_f

    mul     $v0     $v0     MAP_SIZE
    add     $v0     $v0     $v1
    add     $v0     $v0     $t8         # &map[p.r * size + p.c]
    lb      $v0     0($v0)              # map[p.r * size + p.c]

    beq     $v0     2       ret_f       # wall
    j       ret_t

ret_f:
    li      $v0     0
    jr      $ra

ret_t:
    li      $v0     1
    jr      $ra

# a0 stores a pointer to the map array
# a1 stores the current Point
# a2 stores the pointer to end of out array
# v0 is new end of array
get_neighbors:
    sub     $sp     $sp     24
    sw      $ra     0($sp)
    sw      $s0     4($sp)
    sw      $s1     8($sp)
    sw      $s2     12($sp)
    sw      $s3     16($sp)
    sw      $s4     20($sp)

    move    $s0     $a0                 # map
    move    $s1     $a2                 # arr

    move    $a0     $a1
    jal     get_point
    move    $s2     $v0                 # p.r
    move    $s3     $v1                 # p.c

neighbor_north:
    sub     $a0     $s2     1           # make north
    move    $a1     $s3
    jal     make_point
    move    $s4     $v0                 # n

    move    $a0     $s0                 # map
    move    $a1     $s4                 # n
    jal     is_walkable

    beq     $v0     0       neighbor_south
    sw      $s4     0($s1)              # append
    add     $s1     $s1     4

neighbor_south:
    add     $a0     $s2     1           # make south
    move    $a1     $s3
    jal     make_point
    move    $s4     $v0                 # s

    move    $a0     $s0                 # map
    move    $a1     $s4                 # s
    jal     is_walkable

    beq     $v0     0       neighbor_east
    sw      $s4     0($s1)              # append
    add     $s1     $s1     4

neighbor_east:
    move    $a0     $s2
    add     $a1     $s3     1           # make east
    jal     make_point
    move    $s4     $v0                 # e

    move    $a0     $s0                 # map
    move    $a1     $s4                 # e
    jal     is_walkable

    beq     $v0     0       neighbor_west
    sw      $s4     0($s1)              # append
    add     $s1     $s1     4

neighbor_west:
    move    $a0     $s2
    sub     $a1     $s3     1           # make west
    jal     make_point
    move    $s4     $v0                 # w

    move    $a0     $s0                 # map
    move    $a1     $s4                 # w
    jal     is_walkable

    beq     $v0     0       neighbor_end
    sw      $s4     0($s1)              # append
    add     $s1     $s1     4

neighbor_end:
    move    $v0     $s1                 # arr
    lw      $ra     0($sp)
    lw      $s0     4($sp)
    lw      $s1     8($sp)
    lw      $s2     12($sp)
    lw      $s3     16($sp)
    lw      $s4     20($sp)
    add     $sp     $sp     24
    jr      $ra

# a0 is the element to push
# a1 is the size of the heap
# v0 is the new size of heap
push_heap:
    la      $t0     heap                # heap
    mul     $t1     $a1     4
    add     $t0     $t0     $t1         # &heap[size]    

    move    $t1     $a1                 # index
    sub     $t2     $a1     1           # parent
    div     $t2     $a1     2

    sw      $a0     0($t0)              # append to heap
    la      $t0     heap                # heap

heapify_up:
    ble     $t1     0       push_end

    la      $t8     distances
    la      $t9     heuristic

    mul     $t3     $t1     4           # &heap[index]
    add     $t3     $t0     $t3         
    lw      $t4     0($t3)              # heap[index]

    mul     $t5     $t4     4           # 4 * heap[index]
    add     $t6     $t8     $t5
    lw      $t6     0($t6)              # dist[heap[index]]
    add     $t5     $t9     $t5
    lw      $t5     0($t5)              # heur[heap[index]]
    add     $t5     $t5     $t6         # dist + heur [heap[index]]

    mul     $t6     $t2     4           # &heap[parent]
    add     $t6     $t0     $t6         
    lw      $t7     0($t6)              # heap[parent]
    mul     $t7     $t7     4           # 4 * heap[parent]

    add     $t8     $t7     $t8         # &dist[heap[parent]]
    add     $t9     $t7     $t9         # &heur[heap[parent]]
    lw      $t8     0($t8)              # dist[heap[parent]]
    lw      $t9     0($t9)              # heur[heap[parent]]
    add     $t8     $t8     $t9         # dist + heur [heap[parent]]

    bge     $t5     $t8     push_end    # dist + heur [heap[index]] >= dist + heur [heap[parent]]

    sw      $t4     0($t6)              # heap[parent] = heap[index]
    div     $t7     $t7     4
    sw      $t7     0($t3)              # heap[index] = heap[parent]

    move    $t1     $t2                 # index = parent
    sub     $t2     $t2     1           # parent = (index - 1) / 2
    div     $t2     $t2     2

    j       heapify_up
    
push_end:
    add     $v0     $a1     1           # increment heap size
    jr      $ra
    
# a0 is the size of the heap
# v0 is the popped element
# v1 is the new size of heap
pop_heap:
    la      $t0     heap

    lw      $v0     0($t0)              # heap[0]
    sub     $v1     $a0     1           # --heap.size

    mul     $t1     $v1     4           # &heap[heap.size]
    add     $t1     $t1     $t0
    lw      $t1     0($t1)              # heap[heap.size]
    sw      $t1     0($t0)              # heap[0] = heap[heap.size]

    li      $t1     0                   # index

heapify_down:
    bge     $t1     $v1     pop_end

    mul     $t2     $t1     2           # left
    add     $t2     $t2     1
    add     $t3     $t2     1           # right
    move    $t4     $t1                 # smaller

left_smaller:
    bge     $t2     $v1     pop_end
 
    mul     $t5     $t4     4
    add     $t5     $t5     $t0         # &heap[smaller]
    lw      $t5     0($t5)              # heap[smaller]
    mul     $t5     $t5     4           # 4 * heap[smaller]

    la      $t6     distances
    add     $t6     $t6     $t5
    lw      $t6     0($t6)              # dist[heap[smaller]
    la      $t7     heuristic
    add     $t5     $t7     $t5
    lw      $t5     0($t5)              # heur[heap[smaller]
    add     $t5     $t5     $t6         # dist + heuristic [heap[smaller]]

    mul     $t6     $t2     4           # &heap[left]
    add     $t6     $t6     $t0
    lw      $t6     0($t6)              # heap[left]
    mul     $t6     $t6     4           # 4 * heap[left]

    la      $t7     distances
    add     $t7     $t7     $t6
    lw      $t7     0($t7)              # dist[heap[left]]
    la      $t8     heuristic
    add     $t6     $t6     $t8
    lw      $t6     0($t6)              # heuristic[heap[left]]
    add     $t6     $t6     $t7         # dist[h[left]] + heu[h[left]]

    bge     $t6     $t5     right_smaller
    move    $t4     $t2

right_smaller:
    bge     $t3     $v1     pop_end
 
    mul     $t5     $t4     4
    add     $t5     $t5     $t0         # &heap[smaller]
    lw      $t5     0($t5)              # heap[smaller]
    mul     $t5     $t5     4           # 4 * heap[smaller]

    la      $t6     distances
    add     $t6     $t6     $t5
    lw      $t6     0($t6)              # dist[heap[smaller]
    la      $t7     heuristic
    add     $t5     $t7     $t5
    lw      $t5     0($t5)              # heur[heap[smaller]
    add     $t5     $t5     $t6         # dist + heuristic [heap[smaller]]

    mul     $t6     $t3     4           # &heap[right]
    add     $t6     $t6     $t0
    lw      $t6     0($t6)              # heap[right]
    mul     $t6     $t6     4           # 4 * heap[right]

    la      $t7     distances
    add     $t7     $t7     $t6
    lw      $t7     0($t7)              # dist[heap[right]]
    la      $t8     heuristic
    add     $t6     $t6     $t8
    lw      $t6     0($t6)              # heuristic[heap[right]]
    add     $t6     $t6     $t7         # dist[h[right]] + heu[h[right]]

    bge     $t6     $t5     parent_smaller
    move    $t4     $t3

parent_smaller:
    beq     $t4     $t1     pop_end

    mul     $t2     $t4     4           # &heap[smaller]
    add     $t2     $t2     $t0
    lw      $t3     0($t2)              # heap[smaller]

    mul     $t5     $t1     4           # &heap[index]
    add     $t5     $t5     $t0
    lw      $t6     0($t5)              # heap[index]

    sw      $t6     0($t2)              # heap[smaller] = heap[index]
    sw      $t3     0($t5)              # heap[index] = heap[smaller]

    move    $t1     $t4
    j       heapify_down

pop_end:
    jr      $ra

# a0 stores the pointer to map
# a1 stores the start index
# a2 stores the end index
# requires heuristic to be preset
# requires seen to be reset to 0
# requires dist to be reset to 2000
# v0 stores the size of the path (end to start)
pathfind:
    sub     $sp     $sp     36
    sw      $ra     0($sp)
    sw      $s0     4($sp)
    sw      $s1     8($sp)
    sw      $s2     12($sp)
    sw      $s3     16($sp)
    sw      $s4     20($sp)
    sw      $s5     24($sp)
    sw      $s6     28($sp)
    sw      $s7     32($sp)

    move    $s0     $a0                 # map
    move    $s1     $a2                 # target
    move    $s7     $a1                 # start

    la      $s2     heap
    sw      $a1     0($s2)              # heap[0] = start
    li      $s2     1                   # size of heap

astar:
    move    $a0     $s2                 # size of heap

    jal     pop_heap
    move    $s2     $v1                 # update heap size
    move    $s3     $v0                 # p

    la      $t6     seen
    add     $t7     $t6     $s3         # &seen[p]    
    lb      $t6     0($t7)              # seen[p]
    beq     $t6     1       astar       # seen[p] -> continue
    li      $t6     1                   # seen[p] = true
    sb      $t6     0($t7)

    beq     $s3     $s1     make_path   # p == end -> break

    la      $t0     distances
    mul     $t1     $s1     4
    add     $t0     $t0     $t1         # &dist[p]
    lw      $s4     0($t0)              # dist[p]
    add     $s4     $s4     1           # dist[p] + 1

    div     $a0     $s3     MAP_SIZE
    rem     $a1     $s3     MAP_SIZE
    jal     make_point

    move    $a0     $s0
    move    $a1     $v0
    la      $a2     neighbors
    move    $s5     $a2                 # copy neighbors start
    jal     get_neighbors
    move    $s6     $v0                 # copy neighbors end

for_all_neighbors:
    beq     $s5     $s6     astar

    lhu     $t0     0($s5)              # q.r
    lhu     $t1     2($s5)              # q.c
    mul     $t3     $t0     MAP_SIZE
    add     $t3     $t3     $t1         # q.pos

    la      $t6     seen
    add     $t7     $t6     $t3         # &seen[q]
    lb      $t6     0($t7)              # seen[q]
    beq     $t6     1       for_all_inc # seen[q] -> continue

    la      $t2     distances

    mul     $t4     $t3     4
    add     $t4     $t4     $t2         # &[dist[q.pos]]
    lw      $t5     0($t4)              # dist[q.pos]

    beq     $t5     2000    do_work     # dist[q] == 2000
    bge     $t5     $s4     do_work     # dist[q] >= dist[p] + 1
    j       for_all_inc

do_work:
    mul     $t6     $t3     4           # q.pos * 4

    la      $t7     parents
    add     $t7     $t6     $t7         # &parents[q]
    sw      $s3     0($t7)              # parents[q] = p

    la      $t7     distances
    add     $t7     $t6     $t7         # &dist[q]
    sw      $s4     0($t7)              # dist[q] = dist[p] + 1

    move    $a0     $t3                 # q.pos
    move    $a1     $s2                 # size of heap
    jal     push_heap
    move    $s2     $v0                 # new size of heap

for_all_inc:
    add     $s5     $s5     4
    j       for_all_neighbors

make_path:
    move    $t0     $s1                 # cur
    la      $t1     path                # &path[size]
    la      $t2     parents             # &parents[0]
    li      $v0     0                   # size

make_path_loop:
    sw      $t0     0($t1)              # path.append(cur)
    add     $t1     $t1     4
    add     $v0     $v0     1

    mul     $t0     $t0     4
    add     $t0     $t0     $t2
    lw      $t0     0($t0)              # cur = parents[cur]

    beq     $t0     $s7     make_path_end
    j       make_path_loop

make_path_end:
    sw      $s7     0($t1)              # append the start

    lw      $ra     0($sp)
    lw      $s0     4($sp)
    lw      $s1     8($sp)
    lw      $s2     12($sp)
    lw      $s3     16($sp)
    lw      $s4     20($sp)
    lw      $s5     24($sp)
    lw      $s6     28($sp)
    lw      $s7     32($sp)
    add     $sp     $sp     36
    jr      $ra

# a0 stores the end position
# calculates the heuristics
# reset the seen        (0)
# reset the distances   (2000)
pathfind_init:
    li      $t0     0
    la      $t1     heuristic
    la      $t2     distances
    la      $t3     seen

    li      $t4     2000                    # 2000 for distance

    div     $t5     $a0     MAP_SIZE        # end.r
    rem     $t6     $a0     MAP_SIZE        # end.c

pathfind_init_loop:
    beq     $t0     1600    pathfind_init_end

    sb      $0      0($t3)                  # seen[index] = 0
    add     $t3     $t3     1

    sw      $t4     0($t2)                  # dist[index] = 2000               
    add     $t2     $t2     4

calculate_heuristic:
    div     $t7     $t0     MAP_SIZE        # cur.r
    rem     $t8     $t0     MAP_SIZE        # cur.c

    sub     $t7     $t7     $t5             # cur.r - end.r
    sub     $t8     $t8     $t6             # cur.c - end.c
    abs     $t7     $t7                     # || dr ||
    abs     $t8     $t8                     # || dc ||

    bge     $t7     $t8     set_row
    j       set_col

set_col:
    sw      $t8     0($t1)
    add     $t1     $t1     4
    j       pathfind_init_loop_inc

set_row:
    sw      $t7     0($t1)
    add     $t1     $t1     4
    j       pathfind_init_loop_inc
    
pathfind_init_loop_inc:
    add     $t0     $t0     1               # ++index
    j       pathfind_init_loop

pathfind_init_end:
    jr      $ra

# ======================= DEBUG HELPERS

# a0 = start of array
# a1 = end of array
print_int_arr:
    beq     $a0     $a1    return_print_int

    li      $v0     1                       # print int
    syscall

    add     $a0     $a0     4
    j       print_int_arr

return_print_int:
    jr      $ra

# a0 = point
print_point:
    sub     $sp     $sp     8
    sw      $ra     0($sp)
    sw      $s0     4($sp)
    move    $s0     $a0   

    jal     get_point
    move    $a0     $v0
    li      $v0     1
    syscall                                 # print p.r

    move    $a0     $s0
    jal     get_point
    move    $a0     $v1
    li      $v0     1
    syscall                                 # print p.c

return_print_point:
    lw      $ra     0($sp)
    lw      $s0     4($sp)
    add     $sp     $sp     8
    jr      $ra

GRIDSIZE = 4                    ## Sudoku
GRID_SQUARED = 16
ALL_VALUES = 65535
sudoku_solve:
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

    la      $t0 path
    sw      $t0 path_pos    
    sw      $t0 path_end
    li      $t0 1
    sb      $t0 path_done

    li      $t0     0
    sw      $t0     SHOOT
    li      $t0     1
    sw      $t0     SHOOT
    li      $t0     2
    sw      $t0     SHOOT
    li      $t0     3
    sw      $t0     SHOOT

    j       interrupt_dispatch      # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    li      $t0 1
    sb      $t0 has_puzzle        

    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK

    sw      $0  VELOCITY

    la      $t0 path
    sw      $t0 path_pos    
    sw      $t0 path_end
    li      $t0 1
    sb      $t0 path_done    

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
    # if we are on the buffer path,
    # then go immediately to the ready path
    # otherwise we are done with path
    lw      $t0     path_end
    la      $t1     path_buf

    bne     $t0     $t1         end_path

    lb      $t0     buf_ready
    bne     $t0     $0          end_buffer_path

    j       interrupt_dispatch

end_path:
    li      $t0     1
    sb      $t0     path_done
    j       interrupt_dispatch

end_buffer_path:
    sb      $0      buf_ready

    la      $t0     path
    sw      $t0     path_end
    lw      $t1     path_len
    mul     $t1     $t1     4
    add     $t0     $t0     $t1
    sw      $t0     path_pos

    lw      $t0     TIMER               # start the bot chasing  
    add     $t0     $t0     500
    sw      $t0     TIMER    

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