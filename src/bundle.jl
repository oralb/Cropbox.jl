abstract type BundleOperator end

struct BundleAll <: BundleOperator end
struct BundleRecursiveAll <: BundleOperator end
struct BundleIndex{I<:Number} <: BundleOperator
    index::I
end
struct BundleFilter{S<:AbstractString} <: BundleOperator
    cond::S
end

struct Bundle
    root::Produce
    ops::Vector{BundleOperator}
end

import Base: getindex, getproperty
getindex(s::Produce, ops::AbstractString) = begin
    resolve(op::AbstractString) = begin
        if op == "*"
            # collecting children only at the current level
            BundleAll()
        elseif op == "**"
            # collecting all children recursively
            BundleRecursiveAll()
        else
            i = tryparse(Int, op)
            if !isnothing(i)
                BundleIndex(i)
            else
                #TODO: support generic indexing function?
                BundleFilter(op)
            end
        end
    end
    Bundle(s, resolve.(split(ops, "/")))
end
getproperty(b::Bundle, p::Symbol) = begin
    l = map(s -> getproperty(s, p), collect(b))
    @show l
    l
end

import Base: collect
collect(b::Bundle) = reduce((a, b) -> collect(a, b), [getfield(b, :root), getfield(b, :ops)...])
collect(p::Produce, ::BundleAll) = value(p)
collect(p::Produce, ::BundleRecursiveAll) = begin
    S = value(p)
    l = System[]
    #TODO: possibly reduce overhead by reusing calculated values in child nodes
    f(S) = (append!(l, S); foreach(s -> f.(value(getproperty(s, p.name))), S); l)
    f(S)
end
collect(S::Vector{<:System}, o::BundleIndex) = begin
    n = length(S)
    i = o.index
    i = (i >= 0) ? i : n+i+1
    (1 <= i <= n) ? [S[i]] : System[]
end
collect(S::Vector{<:System}, o::BundleFilter) = filter(s -> value(getproperty(s, Symbol(o.cond))), S)
