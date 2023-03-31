#structs
#Qustions to prof: what should the Object class contain?, What is the hiarchy of classes? What is the difference between Class and Object?
# How should GenericFunction have slots? How can MultiMethod have slots?

mutable struct Instance
    name::Symbol
    slots::Dict{Symbol, Any}
    instance_of::Any
end

Class = Instance(:Class, Dict{Symbol, Any}(), nothing)
Class.slots[:direct_slots] = [:name, :direct_superclasses, :direct_slots]
setfield!(Class, :instance_of, Class)
Top = Instance(:Top, Dict{Symbol, Any}(), Class)
Object = Instance(:Object, Dict{Symbol, Any}(), Class)
Class.slots[:direct_superclasses] = [Object]
Object.slots[:direct_superclasses] = [Top]

#functions
function create_class(name::Symbol, superclasses::Vector, slots_for_instances::Vector{Symbol})
    if isempty(superclasses)
        push!(superclasses, Object)
    end
    slots = Dict{Symbol, Any}()
    direct_slots = getfield(Class, :slots)[:direct_slots]

    slots[direct_slots[1]] = name
    slots[direct_slots[2]] = superclasses
    slots[direct_slots[3]] = slots_for_instances
    return Instance(name, slots, Class)
end

function new(class::Instance, ;kwargs...)
    slots_from_class = getfield(class, :slots)[:direct_slots]
    slots = Dict{Symbol, Any}()
    for (first, second) in kwargs
        if first in slots_from_class
            slots[first] = second
        else
            error("ERROR: Slot $(first) is missing\n...")
        end
    end
    return Instance(:nothing, slots, class)
end

function Base.getproperty(instance::Instance, get::Symbol)
    all_slots = getfield(instance,:slots)
    if get == :slots
        if haskey(all_slots, :direct_slots)
            return all_slots[:direct_slots]
        else
            error("ERROR: Slot $(slot) is missing\n...")
        end
    end
    if haskey(all_slots, get)
        if !isnothing(all_slots[get])
            return all_slots[get]
        else
            error("ERROR: Slot $(slot) is unbound\n...")
        end
    else
        error("ERROR: Slot $(slot) is missing\n...")
    end
end
Class.slots
ComplexNumber = create_class(:ComplexNumber, [], [:real, :imag])
ComplexNumber.direct_slots

function Base.setproperty!(instance::Instance, set::Symbol, val::Any)
    all_slots = getfield(instance,:slots)
    if haskey(all_slots, set)
        all_slots[set] = val
    else
        error("ERROR: Slot $(slot) is missing\n...")
    end
end
ComplexNumber = create_class(:ComplexNumber, [], [:real, :imag])
c1 = new(ComplexNumber, real=5, imag=2)
c1.real
c1.real = 10
c1.real

GenericFunction = Instance(:GenericFunction, Dict{Symbol, Any}(),[:name, :methods, :args], Class)
gen_func_slots = getfield(GenericFunction, :slots)
gen_func_slots[:direct_superclasses] = [Object]
GenericFunction.slots

MultiMethod = Instance(:MultiMethod, Dict{Symbol, Any}(),[:specializers, :procedure, :generic_function], Class)
multi_method_slots = getfield(MultiMethod, :slots)
multi_method_slots[:direct_superclasses] = [Object]
MultiMethod.slots
#####################################

# THIS DOES NOT ALLOW MULTIPLE FUNCTIONS WITH THE SAME NAME BUT DIFFERENT NUMBER OF ARGUMENTS
gen_functions = Dict{Symbol, GenericFunction}()

function make_generic(name::Symbol, args...)
    slots = Dict{Symbol, Any}()
    object_slots = getfield(GenericFunction, :slots_for_instance)
    slots[1] = name
    slots[2] = []
    slots[3] = length(args)
    gen_func = Instance(name, Dict{Symbol, Any}(), slots, :GenericFunction)
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
GenericFunction.slots #[:name, :methods, ...]
MultiMethod.slots # [:specializers, :procedure, :generic_function, ...]

add