include("solver.jl")

inp = readlines("slitherlink/problem.txt")
width, height = parse.(Int, split(inp[1]))
problem = inp[2]

font_size = 40
scale_factor = 100; margin = 100
output_width = width * scale_factor + margin
output_height = height * scale_factor + margin
Drawing(output_width, output_height, "slitherlink/solution.png")

background("white")
setlinecap("round")
setlinejoin("round")
setcolor("black")
setline(10)
fontsize(font_size)

draw_background(width, height)

boardset = BoardSet(width, height)
boardset.board = parse_problem(problem, width, height)

boardset.hor_lines[2,2] = 0

boardset_temp = BoardSet(width, height)
boardset_temp.board = copy(boardset.board)
@time solve_puzzle!(boardset_temp, 1)
@time solve_puzzle!(boardset, 1)

draw_board(boardset.board)
draw_solution(boardset.hor_lines, boardset.ver_lines)

println(verify_constraints(boardset))
println(encode_solution(boardset))

finish()
preview()