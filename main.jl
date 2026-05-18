using ArgParse
include("solver.jl")

s = ArgParseSettings(
    description = "Solve the slitherlink"
)

@add_arg_table s begin
    "--only-preprocess", "-o"
        help = "Only do the preprocess part without DFS"
        action = :store_true
    
    "--print-solution", "-p"
        help = "Print the encoded solution"
        action = :store_true
end

args = parse_args(s)

onlyPreprocess = args["only-preprocess"]
printSolution = args["print-solution"]

inp = readlines("problem.txt")
width, height = parse.(Int, split(inp[1]))
problem = inp[2]

boardset = BoardSet(width, height)

# Repeat multiple times for correct time measurement
for iter=1:2
    global boardset
    boardset = BoardSet(width, height)
    boardset.board = parse_problem(problem, width, height)

    @time solve_puzzle!(boardset; onlyPreprocess=onlyPreprocess)
end

verify = verify_constraints(boardset)
if verify
    println("Succeeded solving")
else
    println("Failed solving.")
end

if printSolution println(encode_solution(boardset)) end

# Draw board
begin
    font_size = 40
    scale_factor = 100; margin = 100
    output_width = width * scale_factor + margin
    output_height = height * scale_factor + margin
    Drawing(output_width, output_height, "solution.png")

    background("white")
    setlinecap("round")
    setlinejoin("round")
    setcolor("black")
    setline(10)
    fontsize(font_size)

    draw_background(width, height)

    draw_board(boardset.board)
    draw_solution(boardset.hor_lines, boardset.ver_lines)
    finish()
end

preview()