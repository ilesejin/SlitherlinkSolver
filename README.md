# SlitherlinkSolver
Julia Implementation of a Slitherlink Solver

This is a project for the Programming course (2026) in Charles University. 

## Solver

The solver consists of two parts: preprocessing and DFS. 

### Preprocessing

Uses well-known slitherlink patterns to solve without any guessing. The solver has a queue for fixing the line. Each time, the solver pops one element from the queue, runs `get_valid_single`, adds suggestions to the queue, and fixes the line. The function `get_valid_single` checks if the input is valid and generates suggestions, which are some new lines that can be fixed using the patterns. The list of patterns can be found [here](https://jonathanolson.net/slitherlink/).

### DFS

After preprocessing, the puzzle could be solved or not. If not, the solver starts guessing. It first generates a heatmap using the Gaussian kernel where fixed parts are hot, unfixed parts are cold. Then, it gives the order of the lines from hot to cold. The solver uses heuristics: guesses hot lines first, since they are closer to fixed lines. For each line is guessed, the solver also uses the suggestions generated from `get_valid_single`. 

### Segment End Tracker

One hard part of slitherlink is that the line must be a single loop. Therefore, I implemented the Segment End Tracker. The Segment End Tracker (SET) is a 2d-array which assigns a value to each grid point. When a line is placed, it writes the position of the other end at each ends of the segment. The value at some end of a segment is always the position of the other end of the same segment. This is retained during the extension or concatenation of segments. Therefore, we can detect if a loop is made or not: if the two ends point each other, it must be a loop. Now, we don't have to check every time if a loop is made; SET does everything. 

### 2-chains

There is one cool fact about Slitherlink: the parity of sectors is invariant around a corner. Also, the opposite corners surrounding 2 have the same parity of sectors. Therefore, we search for diagonal 2 chains when we generate suggestions. Refer to the pattern guide for detailed explanation. 

### Problems

The problems are crawled from the website https://www.puzzle-loop.com/. There are list of problems in `problem_bank.txt`. Note that this solver cannot solve the final problem, which is the **Monthly Loop**. 

## Performance

The solver takes about 0.01 seconds to solve a 25x30 Hard Slitherlink. Note that the solver doesn't even go to the DFS stage for 25x30 Hard Slitherlinks; everything is solved in the preprocess stage. This solver can solve every problem available in the website within 0.01 seconds, except for the **Monthly Loop**. The **Monthly Loop** requires too much DFS steps, so the solver seems to take too much time.

The robot solver `exabyte_bot` [here](https://www.puzzle-loop.com/hall.php) is me. 0.2 seconds in the hall of fame is mostly the network communication time. I guess this solver will achieve rank #1 if I could execute this somewhere in California (where the server is located).

## Submission

`submit.jl` is a code for submission to the [website](https://www.puzzle-loop.com/). It requests a problem from the website, solves and submits it, and the website verifies the solution. If you provide your api token in `api_token.txt`, you can even submit your solution into the hall of fame. 