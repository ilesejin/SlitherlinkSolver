using HTTP, ArgParse, Printf
include("solver.jl")

s = ArgParseSettings(
    description = "Solve and submit using the website https://www.puzzle-loop.com/"
)

@add_arg_table s begin
    "--size", "-s"
        help = "Size parameter of the puzzle. Refer the website."
        arg_type = Int
        default = 9

    "--disable-draw", "-d"
        help = "Disable drawing"
        action = :store_true

    "--fame", "-f"
        help = "Submit to the hall of fame. The api token is required."
        action = :store_true

    "--print-problem", "-p"
        help = "Print the encoded problem."
        action = :store_true
end

args = parse_args(s)

size_param = args["size"]
will_draw = !args["disable-draw"]
fame = args["fame"]
print_problem = args["print-problem"]

apitoken = ""
if fame
    global apitoken
    apitoken = readline("api_token.txt")
end

# Init variables
width, height = 5, 5
boardset = BoardSet(width, height)
sol = ""

# HTTP
url = "https://www.puzzle-loop.com/?size=$size_param"
headers = [
    "User-Agent" => "Julia HTTP Client",
    "Accept" => "application/json",
    "Cookie" => "api_token=$apitoken"
]
jar = HTTP.CookieJar()

form_data = Dict(
    "new" => "1"
)

# Get new puzzle
response = HTTP.post(url, headers, body=form_data, cookies=true, cookiejar=jar)
body_str = String(response.body)
param = body_str
param = split(param, "param")[end]
param = split(param, '"')[3]

submit_data = Dict(
    "robot" => "1",
    "ansH" => "",
    "ready" => "+++Done+++",
    "param" => param
)

# Repeat two times for compilation
for r=1:2
    global form_data, submit_data, response, body_str, param, problem, sol
    global width, height, boardset

    # Extract data
    wh = split(body_str, "puzzleWidth: ")[2]
    width = parse(Int, split(wh, ",")[1])
    wh = split(wh, "puzzleHeight: ")[2]
    height = parse(Int, split(wh, ",")[1])
    boardset = BoardSet(width, height)
    form_data = Dict(
        "param" => param,
        "new" => "1"
    )

    submit_data = Dict(
        "robot" => "1",
        "ansH" => "",
        "ready" => "+++Done+++",
        "param" => param
    )

    # Request new puzzle (To reset timer)
    response = HTTP.post(url, headers, body=form_data, cookies=true, cookiejar=jar)

    t = time()

    # Extract data
    body_str = String(response.body)
    param = body_str
    param = split(param, "name=\"param\" value=")[2]
    param = split(param, '"')[2]
    submit_data["param"] = param

    problem = split(body_str, "task")[2]
    problem = split(problem, "'")[2]

    if print_problem println(problem) end

    # Parse and Solve
    parse_problem!(boardset, problem, width, height)
    verify = solve_puzzle!(boardset)

    if verify
        # Solved puzzle
        # Send to the server
        sol = encode_solution(boardset)
        submit_data["ansH"] = sol
        @printf("Local solving time: %.2f s\n", time() - t)

        response = HTTP.post(url, headers, body=submit_data, cookies=true, cookiejar=jar)

        body_str = String(response.body)

        time_record = body_str
        time_record = split(time_record, "Congratulations! ")[2]
        time_record = split(time_record, "</p>")[1]
        println(time_record)

        if fame
            # Submit to Hall of Fame
            solparams = body_str
            solparams = split(solparams, "solparams")
            if length(solparams) >= 2
                solparams = solparams[2]
                solparams = split(solparams, '"')[3]

                form_data = Dict(
                    "robot" => "1",
                    "solparams" => solparams
                )
                url_post = "https://www.puzzle-loop.com/hallsubmit.php"
                response = HTTP.post(url_post, headers, body=form_data, cookies=true, cookiejar=jar)
            end
        end
    end
end

if will_draw
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
    preview()
end