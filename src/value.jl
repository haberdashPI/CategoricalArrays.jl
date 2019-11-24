leveltype(::Type{<:CategoricalValue{T}}) where {T} = T
leveltype(::Type{T}) where {T} = T
leveltype(x::Any) = leveltype(typeof(x))

# integer type of category reference codes used by categorical value
reftype(::Type{<:CategoricalValue{<:Any, R}}) where {R} = R
reftype(x::Any) = reftype(typeof(x))

pool(x::CategoricalValue) = x.pool
level(x::CategoricalValue) = x.level

# extract the type of the original value from array eltype `T`
unwrap_catvaluetype(::Type{T}) where {T} = T
unwrap_catvaluetype(::Type{T}) where {T >: Missing} =
    Union{unwrap_catvaluetype(nonmissingtype(T)), Missing}
unwrap_catvaluetype(::Type{Union{}}) = Union{} # prevent incorrect dispatch to T<:CategoricalValue method
unwrap_catvaluetype(::Type{Any}) = Any # prevent recursion in T>:Missing method
unwrap_catvaluetype(::Type{T}) where {T <: CategoricalValue} = leveltype(T)

Base.get(x::CategoricalValue) = index(pool(x))[level(x)]
order(x::CategoricalValue) = order(pool(x))[level(x)]

# creates categorical value for `level` from the `pool`
# The result is of type `C` that has "categorical value" trait
catvalue(level::Integer, pool::CategoricalPool{T, R, C}) where {T, R, C} =
    C(convert(R, level), pool)

Base.promote_rule(::Type{C}, ::Type{T}) where {C <: CategoricalValue, T} = promote_type(leveltype(C), T)
Base.promote_rule(::Type{C1}, ::Type{Union{C2, Missing}}) where {C1 <: CategoricalValue, C2 <: CategoricalValue} =
    Union{promote_type(C1, C2), Missing}
# To fix ambiguities with definitions from Base
Base.promote_rule(::Type{C}, ::Type{Missing}) where {C <: CategoricalValue} = Union{C, Missing}
Base.promote_rule(::Type{C}, ::Type{Any}) where {C <: CategoricalValue} = Any

Base.promote_rule(::Type{CategoricalValue{S, R1}},
                  ::Type{CategoricalValue{T, R2}}) where {S, T, R1<:Integer, R2<:Integer} =
    CategoricalValue{promote_type(S, T), promote_type(R1, R2)}
Base.promote_rule(::Type{CategoricalValue{S}},
                  ::Type{CategoricalValue{T}}) where {S, T} =
    CategoricalValue{promote_type(S, T)}

Base.convert(::Type{Ref}, x::CategoricalValue) = RefValue{leveltype(x)}(x)
Base.convert(::Type{String}, x::CategoricalValue) = convert(String, get(x))
Base.convert(::Type{Any}, x::CategoricalValue) = x

# Defined separately to avoid ambiguities
Base.convert(::Type{T}, x::T) where {T <: CategoricalValue} = x
Base.convert(::Type{Union{T, Missing}}, x::T) where {T <: CategoricalValue} = x
Base.convert(::Type{Union{T, Nothing}}, x::T) where {T <: CategoricalValue} = x
# General fallbacks
Base.convert(::Type{S}, x::T) where {S, T <: CategoricalValue} =
    T <: S ? x : convert(S, get(x))
Base.convert(::Type{Union{S, Missing}}, x::T) where {S, T <: CategoricalValue} =
    T <: Union{S, Missing} ? x : convert(Union{S, Missing}, get(x))
Base.convert(::Type{Union{S, Nothing}}, x::T) where {S, T <: CategoricalValue} =
    T <: Union{S, Nothing} ? x : convert(Union{S, Nothing}, get(x))

(::Type{T})(x::T) where {T <: CategoricalValue} = x

Base.Broadcast.broadcastable(x::CategoricalValue) = Ref(x)

function Base.show(io::IO, x::CategoricalValue)
    if nonmissingtype(get(io, :typeinfo, Any)) === nonmissingtype(typeof(x))
        print(io, repr(x))
    elseif isordered(pool(x))
        @printf(io, "%s %s (%i/%i)",
                typeof(x), repr(x),
                order(x), length(pool(x)))
    else
        @printf(io, "%s %s", typeof(x), repr(x))
    end
end

Base.print(io::IO, x::CategoricalValue) = print(io, get(x))
Base.repr(x::CategoricalValue) = repr(get(x))
Base.string(x::CategoricalValue) = string(get(x))
Base.String(x::CategoricalValue{<:AbstractString}) = String(get(x))

@inline function Base.:(==)(x::CategoricalValue, y::CategoricalValue)
    if pool(x) === pool(y)
        return level(x) == level(y)
    else
        return get(x) == get(y)
    end
end

Base.:(==)(::CategoricalValue, ::Missing) = missing
Base.:(==)(::Missing, ::CategoricalValue) = missing

# To fix ambiguities with Base
Base.:(==)(x::CategoricalValue, y::WeakRef) = get(x) == y
Base.:(==)(x::WeakRef, y::CategoricalValue) = y == x

Base.:(==)(x::CategoricalValue, y::AbstractString) = get(x) == y
Base.:(==)(x::AbstractString, y::CategoricalValue) = y == x

Base.:(==)(x::CategoricalValue, y::Any) = get(x) == y
Base.:(==)(x::Any, y::CategoricalValue) = y == x

@inline function Base.isequal(x::CategoricalValue, y::CategoricalValue)
    if pool(x) === pool(y)
        return level(x) == level(y)
    else
        return isequal(get(x), get(y))
    end
end

Base.isequal(x::CategoricalValue, y::Any) = isequal(get(x), y)
Base.isequal(x::Any, y::CategoricalValue) = isequal(y, x)

Base.isequal(::CategoricalValue, ::Missing) = false
Base.isequal(::Missing, ::CategoricalValue) = false

Base.in(x::CategoricalValue, y::AbstractRange{T}) where {T<:Integer} = get(x) in y

Base.hash(x::CategoricalValue, h::UInt) = hash(get(x), h)

# Method defined even on unordered values so that sort() works
function Base.isless(x::CategoricalValue, y::CategoricalValue)
    if pool(x) !== pool(y)
        throw(ArgumentError("CategoricalValue objects with different pools cannot be tested for order"))
    else
        return order(x) < order(y)
    end
end

Base.isless(x::CategoricalValue, y) = order(x) < order(x.pool[get(x.pool, y)])
Base.isless(x::CategoricalValue, y::AbstractString) = order(x) < order(x.pool[get(x.pool, y)])
Base.isless(::CategoricalValue, ::Missing) = true
Base.isless(y, x::CategoricalValue) = order(x.pool[get(x.pool, y)]) < order(x)
Base.isless(y::AbstractString, x::CategoricalValue) = order(x.pool[get(x.pool, y)]) < order(x)
Base.isless(::Missing, ::CategoricalValue) = false

function Base.:<(x::CategoricalValue, y::CategoricalValue)
    if pool(x) !== pool(y)
        throw(ArgumentError("CategoricalValue objects with different pools cannot be tested for order"))
    elseif !isordered(pool(x)) # !isordered(pool(y)) is implied by pool(x) === pool(y)
        throw(ArgumentError("Unordered CategoricalValue objects cannot be tested for order using <. Use isless instead, or call the ordered! function on the parent array to change this"))
    else
        return order(x) < order(y)
    end
end

function Base.:<(x::CategoricalValue, y)
    if !isordered(pool(x))
        throw(ArgumentError("Unordered CategoricalValue objects cannot be tested for order using <. Use isless instead, or call the ordered! function on the parent array to change this"))
    else
        return order(x) < order(x.pool[get(x.pool, y)])
    end
end

Base.:<(x::CategoricalValue, y::AbstractString) = invoke(<, Tuple{CategoricalValue, Any}, x, y)
Base.:<(::CategoricalValue, ::Missing) = missing

function Base.:<(y, x::CategoricalValue)
    if !isordered(pool(x))
        throw(ArgumentError("Unordered CategoricalValue objects cannot be tested for order using <. Use isless instead, or call the ordered! function on the parent array to change this"))
    else
        return order(x.pool[get(x.pool, y)]) < order(x)
    end
end

Base.:<(y::AbstractString, x::CategoricalValue) = invoke(<, Tuple{Any, CategoricalValue}, y, x)
Base.:<(::Missing, ::CategoricalValue) = missing

# JSON of CategoricalValue is JSON of the value it refers to
JSON.lower(x::CategoricalValue) = JSON.lower(get(x))
DataAPI.defaultarray(::Type{CategoricalValue{T, R}}, N) where {T, R} =
  CategoricalArray{T, N, R}
DataAPI.defaultarray(::Type{Union{CategoricalValue{T, R}, Missing}}, N) where {T, R} =
  CategoricalArray{Union{T, Missing}, N, R}