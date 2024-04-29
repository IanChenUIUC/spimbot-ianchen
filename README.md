adversary.s         - the default adversary
my_adversary.s      - a rover that moves around 4 corners on the map
pathfinder.s        - the A* implementation
solver.s            - Matt Handzel's very beefed up sudoku solver
solver_default.s    - the default sudoku solver
spimbot_only.s      - the spimbot specific code and interrupt handler
spimbot.s           - combined spimbot_only.s, solver_default.s, pathfinder.s

to run:
-bot(0/1) spimbot.s
-bot(0/1) spimbot_only.s pathfinder.s solver(_default).s
-bot(0/1) my_adversary.s pathfinder.s solver(_default).s