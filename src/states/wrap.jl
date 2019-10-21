struct Wrap{V} <: State{V}
    value::V
end

Wrap(; _value, _...) = begin
    v = _value
    V = typeof(v)
    Wrap{V}(v)
end

wrap(v::V) where V = Wrap{V}(v)
