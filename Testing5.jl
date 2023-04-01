#structs

mutable struct Instance
    slots::Dict{Symbol, Any}
end

Class = Instance(Dict{Symbol, Any}())
Class.slots[:name] = :Class
Class.slots[:instance_of] = Class
Class.slots[:direct_slots] = [:name, :direct_superclasses, :direct_slots]

Top = Instance(Dict{Symbol, Any}())
Top.slots[:name] = :Top
Top.slots[:instance_of] = Class

Object = Instance(Dict{Symbol, Any}())
Object.slots[:name] = :Object
Object.slots[:instance_of] = Class

Class.slots[:direct_superclasses] = [Object]
Object.slots[:direct_superclasses] = [Top]

function new(class::Instance, ;kwargs...)
    slots_from_class = getfield(class, :slots)[:direct_slots]
    slots = Dict{Symbol, Any}()
    for (first, second) in kwargs
        if first in slots_from_class
            slots[first] = second
            if first == :direct_superclasses && class == Class && !isempty(second)
                slots[first] = [Object]
            end
        else
            error("ERROR: Slot $(first) is missing\n...")
        end
    end
    slots[:instance_of] = class
    return Instance(slots)
end

#ComplexNumber = new(Class, name=:ComplexNumber, direct_superclasses=[Object], direct_slots=[:real, :imag])
#c1 = new(ComplexNumber, real=5, imag=2)

macro defclass(classname, superclasses, slots)
    quote
        $(esc(classname)) = new(Class, name=$(QuoteNode(classname)), direct_superclasses=$superclasses, direct_slots=$(map(x->x, slots.args)))
    end
end

@defclass(ComplexNumber, [], [real, imag])

GenericFunction = new(Class, name=:GenericFunction, direct_superclasses=[Object], direct_slots=[:name, :methods, :number_of_args])

macro defgeneric(genericname, args...)
    quote
        $(esc(genericname)) = new(GenericFunction, name=$(QuoteNode(genericname)), methods=[], number_of_args =$(length(args)))
    end
end 

macro defgeneric(x)
    if x.head==:call
        name = x.args[1]
        args = x.args[2:end]
        quote
            $(esc(name)) = new(GenericFunction, name=$(esc(QuoteNode(name))), methods=[], number_of_args =$(length(args)))
        end
    else
        error("ERROR: defgeneric must be called with a function name and arguments\n...")
    end
end

macro defmethod(x)
    if x.head == :call
        name = x.args[1].args[1]
        specializers = x.args[1].args[2:end]
        procedure = x.args[2]
    end
    if !isdefined(Main, name)
        
    end
    if (getfield(name, :instance_of) == GenericFunction && getfield(name, :number_of_args) == length(x.args[2:end]))
        quote
            $(esc(name)) = new(MultiMethod, specializers=$args, procedure=$(esc(x)), generic_function=$(esc(name)))
        end       
    else
        error("ERROR: defmethod must be called with a function name and arguments\n...")
    end
end

add = new(GenericFunction, name=:add, methods=[], number_of_args=2)
add1 = new(MultiMethod, specializers=[Int, Int], procedure=(a, b) -> a + b, generic_function=add)
#@defmethod add(a::ComplexNumber, b::ComplexNumber) = new(ComplexNumber, real=(a.real + b.real), imag=(a.imag + b.imag))


@defgeneric add(a, b)
macro defmethod()
    
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

function Base.setproperty!(instance::Instance, set::Symbol, val::Any)
    all_slots = getfield(instance,:slots)
    if haskey(all_slots, set)
        all_slots[set] = val
    else
        error("ERROR: Slot $(slot) is missing\n...")
    end
end
GenericFunction = new(Class, name=:GenericFunction, direct_superclasses=[Object], direct_slots=[:name, :methods, :number_of_args])
MultiMethod = new(Class, name=:MultiMethod, direct_superclasses=[Object], direct_slots=[:specializers, :procedure, :generic_function])
add1 = new(MultiMethod, specializers=[Int, Int], procedure=(a, b) -> a + b, generic_function=add)
push!(add.methods, add1)
add.methods[1]

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

function class_of(inst::Instance)
    return getfield(inst, :slots)[:instance_of]
end

function create_class(inst::Instance, superclasses::Vector, slots::Vector)
    for slot in slots
        
        for direct_slot in slot
            if isa(direct_slot, Symbol)
                #skapa field med namn direct_slot
                continue
            end
            
            if direct_slot[1] == :reader
                #skapa reader med namn direct_slot[2]
                new()
                continue
            end
            if direct_slot[1] == :writer
                #skapa writer med namn direct_slot[2]
                continue
            end
            if direct_slot[1] == :initform
                #sätt field slots[1] till direct_slot[2]
                continue
            end
            # skapa field med namn direct_slot[1] och initform direct_slot[2]

            
        end
      
    end
    if 


    #new_class = new(Class, name=inst, direct_superclasses=superclasses, direct_slots=slots)
end