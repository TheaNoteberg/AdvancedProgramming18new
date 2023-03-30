#structs
#Qustions to prof: what should the Object class contain?, What is the hiarchy of classes? What is the difference between Class and Object?

abstract type Class end

struct MetaClass 
    name::Symbol
    direct_superclasses::Vector{MetaClass}
    direct_slots::Vector
end


struct Instance
    class::MetaClass
    slotvalues::Dict{Any, Any} 
    slots::Array
end

Object = MetaClass(:Object, [], [])
struct MultiMethod
    name::Symbol
    specializers::Vector
    procedure::Function #NOT SURE ABOUT THIS 
    generic_function::GenericFunction
    #body
end

struct GenericFunction
    name::Symbol
    args::Vector{Symbol}
    methods::Vector{MultiMethod} 
end

#functions
function create_class(name::Symbol, superclasses::Vector, slots::Vector{Symbol})
    if isempty(superclasses)
        push!(superclasses, Object)
    end
    return MetaClass(name, superclasses, slots)
end

function new(name::MetaClass, ;kwargs...)
    slotvalues = Dict{Any, Any}()
    slots = []
    for arg in kwargs
        slotvalues[arg[1]] = arg[2]
        push!(slots, arg[1])
    end
    return Instance(name,slotvalues,slots)
end

function Base.getproperty(name::Instance,slot::Symbol)
    all_slots = getfield(name,:slotvalues)
    if haskey(all_slots, slot)
        if !isnothing(all_slots[slot])
            return all_slots[slot]
        else
            error("ERROR: Slot $(slot) is unbound\n...")
        end
    else
        error("ERROR: Slot $(slot) is missing\n...")
    end
end

function Base.setproperty!(name::Instance, slot::Symbol, Val::Any)
    all_slots = getfield(name,:slotvalues)
    if haskey(all_slots, slot)
        all_slots[slot] = Val
    else
        error("ERROR: Slot $(slot) is missing\n...")
    end
end
#####################################

# THIS DOES NOT ALLOW MULTIPLE FUNCTIONS WITH THE SAME NAME BUT DIFFERENT NUMBER OF ARGUMENTS
gen_functions = Dict{Symbol, GenericFunction}()

function make_generic(name::Symbol,params)
    gen_func = GenericFunction(name,params,MultiMethod[])
    gen_functions[name] = gen_func
    return gen_func
end

function make_multi_method(name::Symbol, args::Vector, func)
    #look for the generic function
    if !haskey(gen_functions, name)
        make_generic(name, args)
    end
    gen_func = gen_functions[name]
    if length(args) == length(gen_func.args)
        push!(gen_func.methods, MultiMethod(name, args, func, gen_func)) 
        return 
    else
        error("Different number of arguments from generic function") 
    end
end

function check_args(method::MultiMethod, args::Vector)
    if length(args) != length(method.specializers)
        return false
    end
    for i in 1:length(args)
        if args[i] != method.specializers[i]
            return false
        end
    end
    return true
end

function run_generic_function(f::GenericFunction, args::Vector)
    applicable_methods = []
    for method in f.methods
        if check_args(method, args)
            push!(applicable_methods, method)
        end
    end
    # find most applicable_methods
    if length(applicable_methods) == 0
        error("No applicable method found")
    end
end

function class_of(object::Instance)
    return getfield(object,:class)
end

function class_of(class::MetaClass)
    return Class
end

function class_of(generic::GenericFunction)
    return GenericFunction
end

Base.slots(::Type{MultiMethod}) = [:name, :specializers, :procedure, :generic_function]

# Object class
# Class hierarchy


############## TESTING ####################
ComplexNumber = create_class(:ComplexNumber, [], [:real, :imag])
class_of(ComplexNumber)

c1 = new(ComplexNumber, real=5, imag=2)
class_of(c1) === ComplexNumber

class_of(class_of(c1)) === Class

Vehicle = create_class(:Vehicle, [], [:wheels, :color])
Car = create_class(:Car, [Vehicle], [:doors, :engine])
fast_car = new(Car, wheels=4, color="red", doors=2, engine="V8")
class_of(class_of(fast_car)) == Vehicle


ComplexNumber.direct_slots
ComplexNumber.direct_superclasses == [Object]
ComplexNumber.name

add = make_generic(:add, [:a, :b])
make_method(:add, [Int, Int], (a, b) -> a+b)
class_of(add) === GenericFunction
GenericFunction.slots
add