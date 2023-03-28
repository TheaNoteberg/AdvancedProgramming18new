macro defclass(name, superclasses, slots...)

    superclasses_body = isempty(superclasses.args) ? [:Any] : superclasses.args
    quote
        struct $name <: $(superclasses_body)
            $(Symbol(slots[1])) # define the first slot
        end
    end
end

@defclass(ComplexNumber, [], [real, imag])

function new(class, args...)
    instance = class()
    for (slot, value) in zip(fieldnames(class), args)
        setfield!(instance, slot, value)
    end
    return instance
end

mutable struct ComplexNumber 
    real
    imag

    ComplexNumber() = new(0, 0)
end


c1 = new(ComplexNumber, real=1, imag=2)


# Section 2.4
struct MethodContainer
    parameters::Tuple
    method::Function
end

struct GenericFunction
    name::Symbol
    methods::Dict{Int, Array{MethodContainer, 1}}
end

add_generic = GenericFunction(:add, Dict())
method = MethodContainer((Int, Int), 
function add(a::Int, b::Int)
    return a + b
end)

if !haskey(add_generic.methods, 2)
    add_generic.methods[2] = Array{MethodContainer, 1}()
end
push!(add_generic.methods[2], method)

if !haskey(add_generic.methods, 3)
    add_generic.methods[3] = Array{MethodContainer, 1}()
end

push!(add_generic.methods[3], MethodContainer((Int, Int, Int), 
function add(a::Int, b::Int, c::Int)
    return (a + b)*c
end))

add_generic.methods[2]

# Section 2.5