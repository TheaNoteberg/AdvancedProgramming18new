macro defclass(name, superclasses, slots...)

    superclasses_body = isempty(superclasses.args) ? [:Any] : superclasses.args
    quote
        struct $name <: $(superclasses_body)
            $(Symbol(slots[1])) # define the first slot
        end
    end
end

@defclass(ComplexNumber, [], [real, imag])
 

###############################################

abstract type Class{T} end
abstract type Object{T} end
abstract type ComplexNumber end


function new(class, kwargs...)
    instance = class().class_of
    for arg in kwargs
        setfield!(instance, arg[1], arg[2])
    end
    return instance
end

struct ComplexNumberClass{T} <: Class{ComplexNumber}
    name::Symbol
    direct_superclasses::Vector{Any}
    direct_slots::Vector{Symbol}
    class_of::Type{T}
end

mutable struct ComplexNumberObject <: Object{ComplexNumberClass}
    real
    imag
end

c1 = new(ComplexNumber, real=1, imag=2)


class_of(c1)







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
print_object_generic = GenericFunction(:print_object, Dict())
method = MethodContainer((Object, IO),
function print_object(obj::Object, io::IO)
    print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>")
end)

method = MethodContainer((ComplexNumber, IO),
function print_object(obj::ComplexNumber, io::IO)
    print(io, "$(c.real)$(c.imag < 0 ? "-" : "+")$(abs(c.imag))i")
end)

c1
# Section 2.6

function class_of(obj)
    return typeof(obj)
end

class_of(c1) == ComplexNumber

# Section 2.6