abstract type State{V} end

#TODO: support call syntax in Julia 1.3
#(s::State)() = value(s)

value(v) = v
value(s::State) = s.value
value(S::Vector{<:State}) = value.(S)

import Base: adjoint
adjoint(s::State) = value(s)

store!(s::State, v) = (s.value = unitfy(v, unit(s)))

import Base: getindex, length, iterate, eltype
getindex(s::State, i) = s
length(s::State) = 1
iterate(s::State) = (s, nothing)
iterate(s::State, i) = nothing
eltype(::Type{<:State{V}}) where V = V

import Unitful: unit
unit(::State{V}) where V = unittype(V)
unittype(V) = ((V <: Quantity) ? unit(V) : nothing)

import Unitful: isunitless
valuetype(::State{V}) where V = V
valuetype(T, ::Nothing) = T
valuetype(T, U::Units) = isunitless(U) ? T : Quantity{T, dimension(U), typeof(U)}
valuetype(::Type{Array{T,N}}, U::Units) where {T,N} = Array{valuetype(T, U), N}

rateunittype(U::Nothing, T::Units) = T^-1
rateunittype(U::Units, T::Units) = (R = U/T; isunitless(R) ? nothing : R)
rateunittype(U::Units, T::Nothing) = U
rateunittype(U::Nothing, T::Nothing) = nothing

timeunittype(U, TU=u"hr") = isnothing(U) ? TU : (dimension(U) == Unitful.𝐓) ? U : TU

struct Nounit{S,U}
    state::S
    unit::U
end

nounit(s::State, u::Units) = Nounit(s, u)
nounit(s::State) = Nounit(s, nothing)
value(s::Nounit) = deunitfy(unitfy(value(s.state), s.unit))

export nounit

abstract type Priority end
struct PrePriority <: Priority end
struct PostPriority <: Priority end

priority(::S) where {S<:State} = priority(S)
priority(::Type{<:State}) = PostPriority()

import Base: show
show(io::IO, s::S) where {S<:State} = begin
    v = value(s)
    r = isnothing(v) ? repr(v) : string(v)
    r = length(r) > 40 ? "<..>" : r
    print(io, r)
end

include("state/hold.jl")
include("state/wrap.jl")
include("state/advance.jl")
include("state/preserve.jl")
include("state/tabulate.jl")
include("state/interpolate.jl")
include("state/track.jl")
include("state/drive.jl")
include("state/call.jl")
include("state/accumulate.jl")
include("state/capture.jl")
include("state/flag.jl")
include("state/produce.jl")
include("state/solve.jl")
