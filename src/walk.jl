using Base.Threads

"""
    nextid(g, dep::Pair)

Find the next available id such that a dead end (a node with no outgoing paths)
along the dependency chain (`dep`) is continued. If there is no such case, it
gives the maximum id (see [`walkdep`](@ref)).
"""
function nextid(g, dep::Pair)
    dep_end, cpaths = walkdep(g, dep)
    @debug "Paths compatible with the dependency chain" dep_end, cpaths
    !haskey(g.index, dep_end) && return get_prop(g)
    @debug "Last node on dependency chain found in index"
    v = g[dep_end]
    length(cpaths) == 0 && return get_prop(g)
    @debug "The number of compatible paths is not 0"
    if outdegree(g, v) > 0
        @debug "Not a dead end. Asigning path $(get_prop(g))"
        return get_prop(g)
    else
        neighbors = inneighbors(g, v)
        @debug neighbors
        # there is only one possible edge
        previ = findfirst(n->on_path(g, n, cpaths, dir=:out), neighbors)
        # check if the node is isolated and there are no ingoing edges
        previ === nothing && return get_prop(g)
        e = Edge(neighbors[previ], v)
        id = g.paths[e] ∩ cpaths
        @debug "Continuing path $id"
        # There cannot be more than one path since ids are unique and a different
        # path id would be neended only if there were a difference "further down"
        # the graph, but this is not the case since this node has no outgoing paths.
        @assert length(id) == 1
        return first(id)
    end
end

"""
    on_path(g, v, path)

Check if the vertex is on the given path.
"""
function on_path(g, v, path; dir=:in)
    !isempty(intersect!(paths_through(g, v, dir=dir), path))
end

"""
    function walkdep(g, dep::Pair; stopcond=(g,v)->false)

Walk along the dependency chain, but only on already existing paths, and return
the last node and the compatible paths.
"""
function walkdep(g, dep::Pair; stopcond=(g,v)->false)
    current_node = dep[1]
    remaining = dep[2]
    pset = Set{eltype(g)}()
    compatible_paths = paths_through(g, current_node, dir=:both)
    # @debug compatible_paths
    while !stopcond(g, current_node)
        if remaining isa Pair
            node = remaining[1]
            possible_paths = paths_through!(empty!(pset), g, node, dir=:in)
            intersect!(possible_paths, compatible_paths)
            if !isempty(possible_paths)
                current_node = node
                intersect!(compatible_paths, possible_paths)
            else
                return current_node, compatible_paths
            end
            remaining = remaining[2]
        else
            # we have reached the end of the dependency chain
            possible_paths = paths_through!(empty!(pset), g, remaining, dir=:in)
            intersect!(possible_paths, compatible_paths)
            if !isempty(possible_paths)
                return remaining, possible_paths
            else
                return current_node, compatible_paths
            end
        end
    end
    return current_node, compatible_paths
end

"""
    walkpath(g, paths, start; dir=:out, stopcond=(g,v)->false)

Walk on the given `paths` starting from `start` and return the last nodes.
If `dir` is specified, use the corresponding edge direction
(`:in` and `:out` are acceptable values).
"""
function walkpath(g, paths, start::Integer; dir=:out, kwargs...)
    if dir == :out
        walkpath(g, paths, start, outneighbors; kwargs...)
    else
        walkpath(g, paths, start, inneighbors; kwargs...)
    end
end

function walkpath(g, paths, start::Integer, neighborfn; stopcond=(g,v)->false,
        parallel_type=:threads)
    length(paths) == 0 && return Set{eltype(g)}()
    result = Vector{eltype(g)}(undef, length(paths))
    p = [paths...]
    if parallel_type == :threads
        @threads for i in eachindex(p)
            result[i] = walkpath(g, p[i], start, neighborfn, stopcond=stopcond)
        end
    else
        for i in eachindex(p)
            result[i] = walkpath(g, p[i], start, neighborfn, stopcond=stopcond)
        end
    end

    return Set{eltype(g)}(result)
end

function walkpath(g, path::Integer, start::Integer, neighborfn; stopcond=(g,v)->false)
    walkpath!(g, path, start, neighborfn, (g,v,n)->nothing, stopcond=stopcond)
end

"""
    walkpath!(g, path, start, neighborfn, action!; stopcond=(g,v)->false)

Walk on the given `path` and take an action at each node. The action is specified
by a function `action!(g, v, neighbors)` and it can modify the graph.
"""
function walkpath!(g, path, start, neighborfn, action!; stopcond=(g,v)->false)
    while !stopcond(g, start)
        neighbors = neighborfn(g, start)
        action!(g, start, neighbors)
        nexti = findfirst(n->on_path(g, n, path), neighbors)
        if nexti isa Nothing
            return start
        end
        start = neighbors[nexti]
    end
    return start
end
