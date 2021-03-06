abstract type AbstractGridWorld <: RLBase.AbstractEnv end

@forward AbstractGridWorld.world get_grid, get_objects, get_num_objects, get_height, get_width
get_half_size(env::AbstractGridWorld) = (2 * (get_height(env) ÷ 4) + 1, 2 * (get_width(env) ÷ 4) + 1)

Random.rand(rng::Random.AbstractRNG, f::Function, env::AbstractGridWorld; max_try = 1000) = rand(rng, f, get_world(env), max_try = max_try)

#####
# utils
#####

macro generate_getters(type)
    T = getfield(__module__, type)::Union{Type,DataType}
    defs = Expr(:block)
    for field in fieldnames(T)
        get = Symbol(:get_, field)
        qn = QuoteNode(field)
        push!(defs.args, :($(esc(get))(instance::$type) = getfield(instance, $qn)))
    end
    return defs
end

macro generate_setters(type)
    T = getfield(__module__, type)::Union{Type,DataType}
    defs = Expr(:block)
    for field in fieldnames(T)
        set = Symbol(:set_, field, :!)
        qn = QuoteNode(field)
        push!(defs.args, :($(esc(set))(instance::$type, x) = setfield!(instance, $qn, x)))
    end
    return defs
end
