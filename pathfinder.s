SIZE = 40

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

    blt     $v0     0       ret_f
    blt     $v1     0       ret_f
    bge     $v0     SIZE    ret_f
    bge     $v1     SIZE    ret_f

    mul     $v0     $v0     SIZE
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

    div     $a0     $s3     SIZE
    rem     $a1     $s3     SIZE
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
    mul     $t3     $t0     SIZE
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

    div     $t5     $a0     SIZE            # end.r
    rem     $t6     $a0     SIZE            # end.c

pathfind_init_loop:
    beq     $t0     1600    pathfind_init_end

    sb      $0      0($t3)                  # seen[index] = 0
    add     $t3     $t3     1

    sw      $t4     0($t2)                  # dist[index] = 2000               
    add     $t2     $t2     4

calculate_heuristic:
    div     $t7     $t0     SIZE            # cur.r
    rem     $t8     $t0     SIZE            # cur.c

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