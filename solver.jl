using Luxor,Colors

mutable struct BoardSet
    width::Int
    height::Int
    board::Matrix{Int}
    hor_lines::Matrix{Int}
    ver_lines::Matrix{Int}
    left::Int
    degree_matrix::Matrix{Int}
    seg_end_tracker::Matrix{Tuple{Int, Int}}
    idxTraversal::Vector{Tuple{Int, Int, Bool}}
    leaf_count::Int

    function BoardSet(width::Int, height::Int)
        new(width, height, fill(0, height, width),
            fill(-1, height+1, width), fill(-1, height, width+1),
            (height+1)*width + height*(width+1),
            fill(0, height+1, width+1),
            fill((-1, -1), height+1, width+1),
            [],
            0)
    end
end

function parse_problem(problem, width, height)
    res = zeros(Int, height, width)
    for i=1:height
        for j=1:width
            res[i,j] = -1
        end
    end
    cnt = 1
    for x in problem
        if isdigit(x)
            res[div(cnt-1, width)+1, (cnt-1)%width+1] = parse(Int, x)
            cnt += 1
        elseif isletter(x)
            cnt += Int(x) - Int('a') + 1
        else
            error("Parsing Error")
            return Nothing
        end
    end
    
    if cnt != width * height + 1
        error("Parsing Error")
        return Nothing
    end

    return res
end

function parse_solution(solution_string, width, height)
    hor_lines = zeros(Int, height+1, width)
    ver_lines = zeros(Int, height, width+1)

    for i in eachindex(solution_string)
        if solution_string[i] == 'y'
            if i <= width * (height+1)
                hor_lines[div(i-1,width)+1, (i-1)%width+1] = 1
            else
                new_i = i - width * (height+1)
                ver_lines[div(new_i-1,width+1)+1, (new_i-1)%(width+1)+1] = 1
            end
        end
    end

    return hor_lines, ver_lines
end

function encode_solution(boardset::BoardSet)
    solution_string = ""
    for i=1:boardset.height+1
        for j=1:boardset.width
            solution_string *= boardset.hor_lines[i,j]==1 ? "y" : "n"
        end
    end

    for i=1:boardset.height
        for j=1:boardset.width+1
            solution_string *= boardset.ver_lines[i,j]==1 ? "y" : "n"
        end
    end

    return solution_string
end

function is_single_loop(boardset)
    left_ones = 0
    for i=1:height+1
        for j=1:boardset.width+1
            if j<=boardset.width
                left_ones += (boardset.hor_lines[i,j]==1)
            end
            if i<=height
                left_ones += (boardset.ver_lines[i,j]==1)
            end
        end
    end

    # Find the first component
    ind = 1
    while ind <= length(boardset.hor_lines)
        if boardset.hor_lines[div(ind-1, boardset.width)+1,(ind-1)%boardset.width+1]==1
            break
        end
        ind += 1
    end
    if ind <= length(boardset.hor_lines)
        hor_trav = copy(boardset.hor_lines)
        ver_trav = copy(boardset.ver_lines)
        y0 = div(ind-1, boardset.width)+1
        x0 = (ind-1)%boardset.width+1
        hor_trav[y0,x0] = 0
        left_ones -= 1
        x = x0+1; y = y0
        while true
            if x<=boardset.width && hor_trav[y,x]==1
                hor_trav[y,x] = 0
                x += 1
            elseif x>1 && hor_trav[y,x-1]==1
                hor_trav[y,x-1] = 0
                x -= 1
            elseif y<=height && ver_trav[y,x]==1
                ver_trav[y,x] = 0
                y += 1
            elseif y>1 && ver_trav[y-1,x]==1
                ver_trav[y-1,x] = 0
                y -= 1
            else
                return false
            end

            left_ones -= 1
            if x==x0 && y==y0
                break
            end
        end

        if left_ones > 0
            return false
        end
    end

    return true
end

function verify_constraints(boardset)
    for i=1:boardset.height
        for j=1:boardset.width
            if boardset.board[i,j]!=-1
                cnt = [0 0 0]
                cnt[boardset.hor_lines[i,j]+2] += 1
                cnt[boardset.hor_lines[i+1,j]+2] += 1
                cnt[boardset.ver_lines[i,j]+2] += 1
                cnt[boardset.ver_lines[i,j+1]+2] += 1
                if cnt[3] != boardset.board[i,j]
                    return false
                end
            end
        end
    end

    for i=1:boardset.height+1
        for j=1:boardset.width+1
            cnt = 0
            if j != boardset.width+1 && boardset.hor_lines[i,j]==-1
                continue
            end
            if j != 1 && boardset.hor_lines[i,j-1]==-1
                continue
            end
            if i != boardset.height+1 && boardset.ver_lines[i,j]==-1
                continue
            end
            if i != 1 && boardset.ver_lines[i-1,j]==-1
                continue
            end
            cnt += (j!=boardset.width+1 && boardset.hor_lines[i,j]==1)
            cnt += (j!=1 && boardset.hor_lines[i,j-1]==1)
            cnt += (i!=boardset.height+1 && boardset.ver_lines[i,j]==1)
            cnt += (i!=1 && boardset.ver_lines[i-1,j]==1)
            if cnt != 0 && cnt != 2
                return false
            end
        end
    end

    return true
end

function verify_total(boardset)
    return (boardset.left==0) && verify_constraints(boardset) && is_single_loop(boardset)
end

@enum Direction NONEDIR RIGHT LEFT DOWN UP
@enum Position NONEPOS RD RU LD LU

#=
00: impossible, end of search
01: only 0 possbile
10: only 1 possbile
11: 0,1 are both possible
=#
function get_valid_single(cur_i, cur_j, is_hor, boardset, fix_res=0b11)

    if get_line(boardset, cur_i, cur_j, is_hor) != -1
        return get_line(boardset, cur_i, cur_j, is_hor), [[], []]
    end

    res = fix_res
    checks = []
    suggestions = [[], []]

    # 1. Number check
    if is_hor
        if cur_i>1
            push!(checks, (cur_i-1, cur_j))
        end
        if cur_i<=height
            push!(checks, (cur_i, cur_j))
        end
    else
        if cur_j>1
            push!(checks, (cur_i, cur_j-1))
        end
        if cur_j<=boardset.width
            push!(checks, (cur_i, cur_j))
        end
    end

    for (i,j) in checks
        if boardset.board[i,j]!=-1
            cnt = [0 0 0]
            vals = [-1 -1 -1 -1]
            edges = [(i, j, true), (i, j, false), (i+1, j, true), (i, j+1, false)]
            for (id, (k,l,h)) in enumerate(edges)
                vals[id] = get_line(boardset, k, l, h)
                cnt[vals[id]+2] += 1
            end

            if cnt[3] >= boardset.board[i,j]
                res &= 0b01
            end
            if cnt[2] >= 4 - boardset.board[i,j]
                res &= 0b10
            end

            if cnt[1]==2
                for (k,l,h) in edges
                    if k==cur_i && l==cur_j && h==is_hor
                        continue
                    end
                    if get_line(boardset, k, l, h) == -1
                        if (res & 0b01 > 0) push!(suggestions[1], (k, l, h, boardset.board[i,j]-cnt[3])) end
                        if (res & 0b10 > 0) push!(suggestions[2], (k, l, h, boardset.board[i,j]-cnt[3]-1)) end
                    end
                end
            elseif (res & 0b01 > 0) && (cnt[2]+1 == 4 - boardset.board[i,j])
                for (k,l,h) in edges
                    if k==cur_i && l==cur_j && h==is_hor
                        continue
                    end
                    if get_line(boardset, k, l ,h) == -1
                        push!(suggestions[1], (k, l, h, 1))
                    end
                end
            elseif (res & 0b10 > 0) && (cnt[3]+1 == boardset.board[i,j])
                for (k,l,h) in edges
                    if k==cur_i && l==cur_j && h==is_hor
                        continue
                    end
                    if get_line(boardset, k, l ,h) == -1
                        push!(suggestions[2], (k, l, h, 0))
                    end
                end
            else
                for x=1:4
                    if edges[x] == (cur_i, cur_j, is_hor)
                        vals[x] = -2
                        break
                    end
                end

                for x=1:4
                    if vals[x]==-1 && vals[1+(x%4)]==-1
                        other_edge = (-1, -1, false)
                        for y=1:4
                            if x!=y && 1+(x%4)!=y && vals[y]!=-2
                                other_edge = edges[y]
                                break
                            end
                        end

                        di = 2*((i-cur_i)+(i-other_edge[1]))+1
                        dj = 2*((j-cur_j)+(j-other_edge[2]))+1
                        ei = (i-cur_i)+(i-other_edge[1])+1
                        ej = (j-cur_j)+(j-other_edge[2])+1
                        fi = 1-ei; fj=1-ej

                        # 2-chain starts
                        chain_i = i; chain_j = j

                        cnt = [0 0 0]
                        new_vals = [-1 -1]
                        check_edge_list = [(chain_i+di+fi, chain_j+dj, true), (chain_i+di, chain_j+dj+fj, false)]
                        for (id, (k,l,h)) in enumerate(check_edge_list)
                            new_vals[id] = get_line(boardset, k, l, h)
                            cnt[new_vals[id]+2] += 1
                        end
                        if cnt[1] != 2
                            if boardset.board[i,j]==3
                                if (res&0b10>0) && get_line(boardset, other_edge...)==1 && cnt[2]==1
                                    for e in check_edge_list
                                        if get_line(boardset, e...)==-1
                                            push!(suggestions[2], (e..., 1))
                                        end
                                    end
                                end
                            elseif boardset.board[i,j]==1
                                if (res&0b01>0) && get_line(boardset, other_edge...)==0 && cnt[1]==1
                                    for e in check_edge_list
                                        if get_line(boardset, e...)==-1
                                            push!(suggestions[1], (e..., cnt[2]))
                                        end
                                    end
                                end
                            elseif boardset.board[i,j]==2
                                if res&0b01>0
                                    if get_line(boardset, other_edge...)!=-1 && cnt[1]==1
                                        for e in check_edge_list
                                            if get_line(boardset, e...)==-1
                                                push!(suggestions[1], (e..., (cnt[3]+get_line(boardset, other_edge...))%2))
                                            end
                                        end
                                    elseif get_line(boardset, other_edge...)==-1 && cnt[1]==0
                                        push!(suggestions[1], (other_edge..., cnt[3]%2))
                                    end
                                end

                                if res&0b10>0
                                    if get_line(boardset, other_edge...)!=-1 && cnt[1]==1
                                        for e in check_edge_list
                                            if get_line(boardset, e...)==-1
                                                push!(suggestions[2], (e..., (cnt[3]+get_line(boardset, other_edge...)+1)%2))
                                            end
                                        end
                                    elseif get_line(boardset, other_edge...)==-1 && cnt[1]==0
                                        push!(suggestions[2], (other_edge..., (cnt[3]+1)%2))
                                    end
                                end
                            end
                        else
                            chain_i += di; chain_j += dj
                            fl = -1
                            while is_in_board(boardset, chain_i, chain_j)
                                if boardset.board[chain_i, chain_j] != 2
                                    break
                                end

                                cnt = [0 0 0]
                                new_vals = [-1 -1]
                                check_edge_list = [(chain_i+ei, chain_j, true), (chain_i, chain_j+ej, false)]
                                for (id, (k,l,h)) in enumerate(check_edge_list)
                                    new_vals[id] = get_line(boardset, k, l, h)
                                    cnt[new_vals[id]+2] += 1
                                end
                                if cnt[1] != 2
                                    fl = 1
                                    break
                                end

                                cnt = [0 0 0]
                                new_vals = [-1 -1]
                                check_edge_list = [(chain_i+di+fi, chain_j+dj, true), (chain_i+di, chain_j+dj+fj, false)]
                                for (id, (k,l,h)) in enumerate(check_edge_list)
                                    new_vals[id] = get_line(boardset, k, l, h)
                                    cnt[new_vals[id]+2] += 1
                                end
                                if cnt[1] != 2
                                    fl = 0
                                    break
                                end

                                chain_i += di; chain_j += dj
                            end
                        end
                    end
                end
            end
        end
    end

    # 2. Node check
    if is_hor
        checks = [(cur_i, cur_j, RIGHT), (cur_i, cur_j+1, LEFT)]
    else
        checks = [(cur_i, cur_j, DOWN), (cur_i+1, cur_j, UP)]
    end

    sum_degree = 0

    for (i,j, cur_id) in checks
        cnt = [0 0 0]
        edges = [(i,j,true), (i,j-1,true), (i,j,false), (i-1,j,false)]
        vals = [-1 -1 -1 -1]
        for (id, (k,l,h)) in enumerate(edges)
            vals[id] = get_line(boardset, k, l, h)
            cnt[vals[id]+2] += 1
        end

        sum_degree += cnt[3]
        
        if cnt[3] >= 2
            res &= 0b01
        end

        if cnt[1] == 1
            res &= 1 << (cnt[3]%2)
        end

        if cnt[1] == 2
            for (k,l,h) in edges
                if k==cur_i && l==cur_j && h==is_hor
                    continue
                end
                if (!h && 1<=k && k<=boardset.height) || (h && 1<=l && l<=boardset.width)
                    if get_line(boardset, k, l, h)==-1
                        if res&0b01>0 push!(suggestions[1], (k, l, h, cnt[3]%2)) end
                        if res&0b10>0 push!(suggestions[2], (k, l, h, (cnt[3]+1)%2)) end
                    end
                end
            end
        elseif (res & 0b10 > 0) && cnt[3] == 1
            for (k,l,h) in edges
                if k==cur_i && l==cur_j && h==is_hor
                    continue
                end
                if (!h && 1<=k && k<=boardset.height) || (h && 1<=l && l<=boardset.width)
                    if get_line(boardset, k, l, h)==-1
                        push!(suggestions[2], (k, l, h, 0))
                    end
                end
            end
        elseif (res & 0b01 > 0) && cnt[2] == 1
            # Check for nearby 3 and 1
            check_pos = Int(cur_id)-1
            zero_id = -1
            for i in eachindex(vals)
                if vals[i] == 0
                    zero_id = i
                end
            end
            if (Int(cur_id) <= 2 && zero_id >= 3) || (Int(cur_id) >= 3 && zero_id <= 2)
                if Int(cur_id) <= 2
                    check_pos += ((zero_id - 1)&0b1)<<1
                else
                    check_pos = ((Int(cur_id) - 1)&0b1)<<1 + zero_id-1
                end
                choose_pos = [(i-1, j-1) (i-1, j) (i, j-1) (i, j)]
                pos_i, pos_j = choose_pos[check_pos + 1]
                if 1<=pos_i && pos_i<=height && 1<=pos_j && pos_j<=width
                    if boardset.board[pos_i, pos_j] == 3
                        set_edges = [xor(0b01, Int(cur_id)-1)+1, xor(0b01, zero_id-1)+1]
                        for e_id in set_edges
                            e1 = edges[e_id]
                            push!(suggestions[1], (e1[1], e1[2], e1[3], 1))
                        end
                    elseif boardset.board[pos_i, pos_j] == 1
                        set_edges = [xor(0b01, Int(cur_id)-1)+1, xor(0b01, zero_id-1)+1]
                        for e_id in set_edges
                            e1 = edges[e_id]
                            push!(suggestions[1], (e1[1], e1[2], e1[3], 0))
                        end
                    elseif boardset.board[pos_i, pos_j] == 2
                        check_edges = [(pos_i, pos_j, true) (pos_i+1, pos_j, true) (pos_i, pos_j, false) (pos_i, pos_j+1, false)]
                        ls = [Int(cur_id), zero_id]
                        for x in eachindex(ls)
                            e1 = check_edges[ls[x]]
                            line_val = get_line(boardset, e1[1], e1[2], e1[3])
                            if line_val != -1
                                e2 = check_edges[ls[3-x]]
                                push!(suggestions[1], (e2[1], e2[2], e2[3], line_val))
                            end
                        end
                    end
                end
            end
        else
            # Check conjunctions
            check_pos = [(i-1, j-1, 0b0101) (i-1, j, 0b0110) (i, j-1, 0b1001) (i, j, 0b1010)]
            for (pos_i,pos_j,mask) in check_pos
                if is_in_board(boardset, pos_i, pos_j) && (mask & (1<<(Int(cur_id)-1)) > 0)
                    other_edge = (0, 0)
                    for x=1:4
                        if (1<<(x-1)) & mask > 0 && x!=Int(cur_id)
                            other_edge = edges[x]
                        end
                    end
                    di = (pos_i - i)*2+1; dj = (pos_j - j)*2+1
                    ei = pos_i-i+1; ej = pos_j-j+1
                    fi = 1-ei; fj = 1-ej

                    # 2-chain starts
                    chain_i = pos_i; chain_j = pos_j

                    cnt = [0 0 0]
                    vals = [-1 -1]
                    check_edge_list = [(chain_i+ei, chain_j, true), (chain_i, chain_j+ej, false)]
                    fl = -1
                    while is_in_board(boardset, chain_i, chain_j)
                        if boardset.board[chain_i, chain_j] != 2
                            break
                        end

                        cnt = [0 0 0]
                        vals = [-1 -1]
                        check_edge_list = [(chain_i+ei, chain_j, true), (chain_i, chain_j+ej, false)]
                        for (id, (k,l,h)) in enumerate(check_edge_list)
                            vals[id] = get_line(boardset, k, l, h)
                            cnt[vals[id]+2] += 1
                        end
                        if cnt[1] != 2
                            fl = 1
                            break
                        end

                        cnt = [0 0 0]
                        vals = [-1 -1]
                        check_edge_list = [(chain_i+di+fi, chain_j+dj, true), (chain_i+di, chain_j+dj+fj, false)]
                        for (id, (k,l,h)) in enumerate(check_edge_list)
                            vals[id] = get_line(boardset, k, l, h)
                            cnt[vals[id]+2] += 1
                        end
                        if cnt[1] != 2
                            fl = 0
                            break
                        end

                        chain_i += di; chain_j += dj
                    end

                    if is_in_board(boardset, chain_i, chain_j)
                        if boardset.board[chain_i, chain_j]==3 && ((res & 0b10) > 0)
                            edge_ls = [(chain_i+ei, chain_j, true, 1), (chain_i, chain_j+ej, false, 1)]
                            for e in edge_ls
                                push!(suggestions[2], e)
                            end
                            push!(suggestions[2], (other_edge..., 0))
                        elseif boardset.board[chain_i, chain_j]==1
                            if (res & 0b10) > 0
                                if get_line(boardset, other_edge...)==0
                                    edge_ls = [(chain_i+ei, chain_j, true, 0), (chain_i, chain_j+ej, false, 0)]
                                    for e in edge_ls
                                        push!(suggestions[2], e)
                                    end
                                else
                                    check_edge_list = [(chain_i+ei, chain_j, true), (chain_i, chain_j+ej, false)]
                                    if get_line(boardset, check_edge_list[1]...)==0 && get_line(boardset, check_edge_list[2]...)==0
                                        push!(suggestions[2], (other_edge..., 0))
                                    end
                                end
                            end
                            if (res & 0b01) > 0
                                if get_line(boardset, other_edge...)==1
                                    edge_ls = [(chain_i+ei, chain_j, true, 0), (chain_i, chain_j+ej, false, 0)]
                                    for e in edge_ls
                                        push!(suggestions[1], e)
                                    end
                                else
                                    check_edge_list = [(chain_i+ei, chain_j, true), (chain_i, chain_j+ej, false)]
                                    if get_line(boardset, check_edge_list[1]...)==0 && get_line(boardset, check_edge_list[2]...)==0
                                        push!(suggestions[1], (other_edge..., 1))
                                    end
                                end
                            end
                        elseif boardset.board[chain_i, chain_j]==2
                            if (res & 0b10) > 0
                                if fl==1
                                    if cnt[2] == 1
                                        for (k,l,h) in check_edge_list
                                            if get_line(boardset, k, l, h)==-1
                                                push!(suggestions[2], (k, l, h, 1))
                                            end
                                        end
                                        if get_line(boardset, other_edge...) == -1
                                            push!(suggestions[2], (other_edge..., 0))
                                        end
                                    elseif cnt[3] == 1 && get_line(boardset, other_edge...)==0
                                        for (k,l,h) in check_edge_list
                                            if get_line(boardset, k, l, h)==-1
                                                push!(suggestions[2], (k, l, h, 0))
                                            end
                                        end
                                    end
                                else
                                    if cnt[3] == 1
                                        for (k,l,h) in check_edge_list
                                            if get_line(boardset, k, l, h)==-1
                                                push!(suggestions[2], (k, l, h, 0))
                                            end
                                        end
                                        push!(suggestions[2], (other_edge..., 0))
                                    elseif get_line(boardset, other_edge...)!=-1 && cnt[1]!=0
                                        set_val = xor(xor(get_line(boardset, other_edge...), cnt[3]), 1)
                                        for (k,l,h) in check_edge_list
                                            if get_line(boardset, k, l, h)==-1
                                                push!(suggestions[2], (k, l, h, set_val))
                                            end
                                        end
                                    elseif get_line(boardset, other_edge...)==-1 && cnt[1]==0
                                        set_val = (cnt[3]+1) % 2
                                        push!(suggestions[2], (other_edge..., set_val))
                                    end
                                end
                            end

                            if (res & 0b01) > 0
                                if get_line(boardset, other_edge...)!=-1 && cnt[1]!=0
                                    set_val = xor(get_line(boardset, other_edge...), cnt[3])
                                    for (k,l,h) in check_edge_list
                                        if get_line(boardset, k, l, h)==-1
                                            push!(suggestions[1], (k, l, h, set_val))
                                        end
                                    end
                                elseif get_line(boardset, other_edge...)==-1 && cnt[1]==0
                                    set_val = cnt[3] % 2
                                    push!(suggestions[1], (other_edge..., set_val))
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if (res & 0b10 > 0) && sum_degree==2
        left_point = (cur_i,cur_j)
        right_point = (0,0)
        if is_hor
            right_point = (cur_i,cur_j+1)
        else
            right_point = (cur_i+1,cur_j)
        end
        if boardset.seg_end_tracker[left_point...] == right_point
            if boardset.leaf_count > 2
                res &= 0b01
            end
        else
            # Prevent
            # TODO: Merge with below
            if boardset.leaf_count > 4
                one_end = boardset.seg_end_tracker[left_point...]
                other_end = boardset.seg_end_tracker[right_point...]
                delta = one_end .- other_end
                if sum(abs2, delta) == 1
                    if one_end[1] == other_end[1]
                        minval = min(one_end[2], other_end[2])
                        push!(suggestions[2], (one_end[1], minval, true, 0))
                    else
                        minval = min(one_end[1], other_end[1])
                        push!(suggestions[2], (minval, one_end[2], false, 0))
                    end
                end
            end
        end
    elseif (res & 0b10 > 0) && sum_degree==1 && boardset.leaf_count > 4
        one_end = (0,0)
        other_end = (0,0)
        if boardset.degree_matrix[checks[1][1], checks[1][2]]==1
            one_end = (checks[2][1], checks[2][2])
            other_end = boardset.seg_end_tracker[checks[1][1], checks[1][2]]
        else
            one_end = (checks[1][1], checks[1][2])
            other_end = boardset.seg_end_tracker[checks[2][1], checks[2][2]]
        end

        delta = one_end .- other_end
        if sum(abs2, delta) == 1
            if one_end[1] == other_end[1]
                minval = min(one_end[2], other_end[2])
                push!(suggestions[2], (one_end[1], minval, true, 0))
            else
                minval = min(one_end[1], other_end[1])
                push!(suggestions[2], (minval, one_end[2], false, 0))
            end
        end
    end

    return res, suggestions
end

function get_line(boardset::BoardSet, i, j, is_hor)
    if (i<1 || j<1
        || (is_hor && (i>boardset.height+1 || j>boardset.width))
        || (!is_hor && (i>boardset.height || j>boardset.width+1))
        )
        return 0
    end
    return is_hor ? boardset.hor_lines[i,j] : boardset.ver_lines[i,j]
end

function set_line!(boardset::BoardSet, i, j, is_hor, val)
    a1 = i; b1 = j; a2 = 0; b2 = 0
    if is_hor
        a2 = i; b2 = j+1
        boardset.hor_lines[i,j] = val
        boardset.degree_matrix[i,j] += val
        boardset.degree_matrix[i,j+1] += val
    else
        a2 = i+1; b2 = j
        boardset.ver_lines[i,j] = val
        boardset.degree_matrix[i,j] += val
        boardset.degree_matrix[i+1,j] += val
    end

    if val==1
        if boardset.degree_matrix[a1,b1]==2 && boardset.degree_matrix[a2,b2]==2
            seg_end1 = boardset.seg_end_tracker[a1, b1]
            seg_end2 = boardset.seg_end_tracker[a2, b2]
            boardset.seg_end_tracker[seg_end2...] = seg_end1
            boardset.seg_end_tracker[seg_end1...] = seg_end2
            boardset.leaf_count -= 2
        elseif boardset.degree_matrix[a1,b1]==2
            seg_end = boardset.seg_end_tracker[a1, b1]
            boardset.seg_end_tracker[a2, b2] = seg_end
            boardset.seg_end_tracker[seg_end...] = (a2, b2)
        elseif boardset.degree_matrix[a2,b2]==2
            seg_end = boardset.seg_end_tracker[a2, b2]
            boardset.seg_end_tracker[a1, b1] = seg_end
            boardset.seg_end_tracker[seg_end...] = (a1, b1)
        else
            boardset.seg_end_tracker[a1, b1] = (a2, b2)
            boardset.seg_end_tracker[a2, b2] = (a1, b1)
            boardset.leaf_count += 2
        end
    end
end

function is_in_board(boardset::BoardSet, i, j)
    return i>=1 && i<=boardset.height && j>=1 && j<=boardset.width
end

function init_idx_traversal!(boardset::BoardSet)
    boardset.idxTraversal = []
    for i=1:boardset.height+1
        for j=1:boardset.width
            push!(boardset.idxTraversal, (i,j,true))
        end

        if i<=boardset.height
            for j=1:boardset.width+1
                push!(boardset.idxTraversal, (i,j,false))
            end
        end
    end
end

function solve_puzzle!(boardset::BoardSet, startIdx)
    if boardset.left==0
        return true
    end

    if boardset.left == boardset.height * (boardset.width + 1) + (boardset.height+1) * boardset.width
        # preprocess
        # 1. detect 0
        queue = []
        for i=1:boardset.height
            for j=1:boardset.width
                if boardset.board[i,j]==0
                    push!(queue, (i, j, true, 0))
                    push!(queue, (i+1, j, true, 0))
                    push!(queue, (i, j, false, 0))
                    push!(queue, (i, j+1, false, 0))
                end
            end
        end

        # 2. detect corner 1, 3
        corners = [(1,1) (1,width) (height,1) (height,width)]
        for (i,j) in corners
            if boardset.board[i,j]==3
                if i==1
                    push!(queue, (i, j, true, 1))
                else
                    push!(queue, (height+1, j, true, 1))
                end

                if j==1
                    push!(queue, (i, j, false, 1))
                else
                    push!(queue, (i, width+1, false, 1))
                end
            elseif boardset.board[i,j]==1
                if i==1
                    push!(queue, (i, j, true, 0))
                else
                    push!(queue, (height+1, j, true, 0))
                end

                if j==1
                    push!(queue, (i, j, false, 0))
                else
                    push!(queue, (i, width+1, false, 0))
                end
            end
        end

        # 3. detect consecutive 3
        i = 1; j = 1
        while is_in_board(boardset, i, j)
            if boardset.board[i,j]==3
                startj = j
                while is_in_board(boardset, i, j) && boardset.board[i,j]==3
                    j += 1
                end
                finj = j-1
                if finj>startj
                    for k=startj:finj+1
                        push!(queue, (i, k, false, 1))
                    end
                    for k=startj+1:finj
                        if is_in_board(boardset, i-1, k)
                            push!(queue, (i-1, k, false, 0))
                        end
                        if is_in_board(boardset, i+1, k)
                            push!(queue, (i+1, k, false, 0))
                        end
                    end
                end
            else
                j += 1
            end
            if !is_in_board(boardset, i, j)
                j = 1
                i += 1
            end
        end

        i = 1; j = 1
        while is_in_board(boardset, i, j)
            if boardset.board[i,j]==3
                starti = i
                while is_in_board(boardset, i, j) && boardset.board[i,j]==3
                    i += 1
                end
                fini = i-1
                if fini>starti
                    for k=starti:fini+1
                        push!(queue, (k, j, true, 1))
                    end
                    for k=starti+1:fini
                        if is_in_board(boardset, k, j-1)
                            push!(queue, (k, j-1, true, 0))
                        end
                        if is_in_board(boardset, k, j+1)
                            push!(queue, (k, j+1, true, 0))
                        end
                    end
                end
            else
                i += 1
            end
            if !is_in_board(boardset, i, j)
                i = 1
                j += 1
            end
        end

        # 4. detect diagonal 3s
        for i=1:boardset.height
            for j=1:boardset.width
                if boardset.board[i,j]==3
                    if j>1
                        st = (i, j)
                        ii = i; jj = j
                        ii += 1
                        jj -= 1
                        while ii<=boardset.height && jj>=1 && boardset.board[ii,jj]==2
                            ii += 1
                            jj -= 1
                        end
                        if ii<=boardset.height && jj>=1 && boardset.board[ii,jj]==3
                            ed = (ii, jj)
                            push!(queue, (st[1], st[2], true, 1))
                            push!(queue, (st[1], st[2]+1, false, 1))
                            push!(queue, (ed[1]+1, ed[2], true, 1))
                            push!(queue, (ed[1], ed[2], false, 1))
                        end
                    end

                    if j<=boardset.width
                        st = (i, j)
                        ii = i; jj = j
                        ii += 1
                        jj += 1
                        while ii<=boardset.height && jj<=boardset.width && boardset.board[ii,jj]==2
                            ii += 1
                            jj += 1
                        end
                        if ii<=boardset.height && jj<=boardset.width && boardset.board[ii,jj]==3
                            ed = (ii, jj)
                            push!(queue, (st[1], st[2], true, 1))
                            push!(queue, (st[1], st[2], false, 1))
                            push!(queue, (ed[1]+1, ed[2], true, 1))
                            push!(queue, (ed[1], ed[2]+1, false, 1))
                        end
                    end
                end
            end
        end

        while length(queue) > 0
            k, l, h, v = popfirst!(queue)
            if get_line(boardset, k, l, h) == -1
                c1, s1 = get_valid_single(k, l, h, boardset, (1<<v))
                set_line!(boardset, k, l, h, v)
                boardset.left -= 1
                append!(queue, s1[v+1])
            end
        end
    end

    if boardset.left==0
        return true
    end

    return false

    if length(boardset.idxTraversal) == 0
        init_idx_traversal!(boardset)
    end

    i,j,is_hor = boardset.idxTraversal[startIdx]

    while get_line(boardset, i, j, is_hor)!=-1
        j += 1
        if is_hor && j==boardset.width+1
            if i>boardset.height
                return false
            end
            is_hor = false
            j = 1
        elseif !is_hor && j==boardset.width+2
            i += 1
            is_hor = true
            j = 1
        end
    end

    cand, suggestions = get_valid_single(i, j, is_hor, boardset)

    if cand==0
        return false
    end

    cand_list = []
    if cand & 0b01 > 0 push!(cand_list, 0) end
    if cand & 0b10 > 0 push!(cand_list, 1) end

    boardset.left -= 1
    degree_matrix_cpy = copy(boardset.degree_matrix)
    tracker_cpy = copy(boardset.seg_end_tracker)
    leaf_count_cpy = boardset.leaf_count
    for cd in cand_list
        set_line!(boardset, i, j, is_hor, cd)
        modified = []
        failed = false
        while length(suggestions[cd+1]) > 0
            k, l, h, v = popfirst!(suggestions[cd+1])
            if get_line(boardset, k, l, h) == -1
                c1, s1 = get_valid_single(k, l, h, boardset)
                if (1<<v) == c1
                    set_line!(boardset, k, l, h, v)
                    boardset.left -= 1
                    append!(suggestions[cd+1], s1[v+1])
                    push!(modified, (k, l, h))
                elseif c1 == 0
                    failed = true
                    break
                end
            end
        end

        if failed
            for (k, l, h) in modified
                set_line!(boardset, k, l, h, -1)
                boardset.left += 1
            end
            boardset.degree_matrix = copy(degree_matrix_cpy)
            boardset.seg_end_tracker = copy(tracker_cpy)
            boardset.leaf_count = leaf_count_cpy
            continue
        end

        if solve_puzzle!(boardset, startIdx+1)
            return true
        end
        for (k, l, h) in modified
            set_line!(boardset, k, l, h, -1)
            boardset.left += 1
        end
        boardset.degree_matrix = copy(degree_matrix_cpy)
        boardset.seg_end_tracker = copy(tracker_cpy)
        boardset.leaf_count = leaf_count_cpy
    end
    set_line!(boardset, i, j, is_hor, -1)
    boardset.left += 1
    return false
end

function draw_background(width, height)
    for i=1:height+1
        for j=1:width+1
            circle(Point(margin/2+(j-1)*scale_factor, margin/2+(i-1)*scale_factor),12,:fill)
        end
    end
end

function draw_board(board)
    for i=1:height
        for j=1:width
            if board[i,j]!=-1
                p = Point((margin+scale_factor)/2+(j-1)*scale_factor, (margin+scale_factor)/2+(i-1)*scale_factor)
                text(string(board[i,j]), p, halign=:center, valign=:middle)
            end
        end
    end
end

function draw_solution(hor_lines, ver_lines)
    for i=1:height+1
        for j=1:width
            if hor_lines[i,j]==1
                p1 = Point(margin/2+(j-1)*scale_factor, margin/2+(i-1)*scale_factor)
                p2 = Point(margin/2+j*scale_factor, margin/2+(i-1)*scale_factor)
                line(p1, p2, :stroke)
            elseif hor_lines[i,j]==0
                setcolor("red")
                p = Point(margin/2+(j-0.5)*scale_factor, margin/2+(i-1)*scale_factor)
                text("x", p, halign=:center, valign=:middle)
                setcolor("black")
            end
        end
    end

    for i=1:height
        for j=1:width+1
            if ver_lines[i,j]==1
                p1 = Point(margin/2+(j-1)*scale_factor, margin/2+(i-1)*scale_factor)
                p2 = Point(margin/2+(j-1)*scale_factor, margin/2+i*scale_factor)
                line(p1, p2, :stroke)
            elseif ver_lines[i,j]==0
                setcolor("red")
                p = Point(margin/2+(j-1)*scale_factor, margin/2+(i-0.5)*scale_factor)
                text("x", p, halign=:center, valign=:middle)
                setcolor("black")
            end
        end
    end

end