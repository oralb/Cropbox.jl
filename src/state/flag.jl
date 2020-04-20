mutable struct Flag{Bool} <: State{Bool}
    value::Bool
end

Flag(; _value, _...) = begin
    Flag{Bool}(_value)
end

genvartype(v::VarInfo, ::Val{:Flag}; _...) = @q Flag{Bool}

geninit(v::VarInfo, ::Val{:Flag}) = false

genupdate(v::VarInfo, ::Val{:Flag}, ::MainStep) = nothing

genpostupdate(v::VarInfo, ::Val{:Flag}) = begin
    @gensym s f q
    if istag(v, :oneway)
        @q let $s = $(symstate(v)),
               $f = $(genfunc(v))
            if !$C.value($s)
                $C.store!($s, $f)
            end
        end
    else
        @q let $s = $(symstate(v)),
               $f = $(genfunc(v))
            $C.store!($s, $f)
        end
    end
end
