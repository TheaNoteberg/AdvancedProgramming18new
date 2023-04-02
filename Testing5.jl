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
Top.slots[:direct_superclasses] = []

Object = Instance(Dict{Symbol, Any}())
Object.slots[:name] = :Object
Object.slots[:instance_of] = Class

Class.slots[:direct_superclasses] = [Object]
Object.slots[:direct_superclasses] = [Top]

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

function new(class::Instance, ;kwargs...)
    slots_from_class = getfield(class, :slots)[:direct_slots]
    slots = Dict{Symbol, Any}()
    for (first, second) in kwargs
        if first in slots_from_class
            slots[first] = second
            if first == :direct_superclasses && class == Class && isempty(second)
                print("object")
                slots[first] = [Object]
            end
        else
            error("ERROR: Slot $(first) is missing\n...")
        end
    end
    slots[:instance_of] = class
    return Instance(slots)
end

macro defclass(classname, superclasses, slots)
    quote
        $(esc(classname)) = new(Class, name=$(QuoteNode(classname)), direct_superclasses=$superclasses, direct_slots=$(map(x->x, slots.args)))
    end
end

@defclass(ComplexNumber, [], [real, imag])
ComplexNumber.direct_superclasses == [Object]

GenericFunction = new(Class, name=:GenericFunction, direct_superclasses=[Object], direct_slots=[:name, :methods, :number_of_args])
MultiMethod = new(Class, name=:MultiMethod, direct_superclasses=[Object], direct_slots=[:specializers, :procedure, :generic_function])
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
@defgeneric add(a, b)

function (inst::Instance)(args...)
    slots = getfield(inst, :slots) 
    if slots[:instance_of] === GenericFunction
        procedure = getfield(slots[:methods][1], :slots)[:procedure]
        # [:specializers, :procedure, :generic_function]
        for method in slots[:methods]
            if check_args(method, args...)
                return method.procedure(args...)
            end
        end
        error("ERROR: No method for $(g) with arguments $(args)\n...")
        return procedure(args...)
    else
        error("ERROR: $(g) is not a generic function\n...")
    end
end

macro defmethod(x)
    pairs = []
    for i in 2:length(x.args[1].args)
        push!(pairs, Pair(x.args[1].args[i].args[1], x.args[1].args[i].args[2]))
    end
    specializers = Tuple(pairs)
    name_symbol = x.args[1].args[1]
    name = name_symbol
    procedure = x.args[2].args[2]
    args = Tuple([first for (first, _) in specializers])

    return quote
        !@isdefined($(name_symbol)) && @defgeneric $(name)($(args...))
        if typeof($(name_symbol)) != Instance || getfield($(name_symbol), :slots)[:instance_of] != GenericFunction
            error("ERROR: $(name_symbol) is not a generic function\n...")
        end
        slots = getfield($(name), :slots)
        function lambda($(args...))
            $(procedure)
        end
        if getfield($(name), :slots)[:number_of_args] == length($specializers)
            push!(slots[:methods], new(MultiMethod, specializers=$specializers, procedure=lambda, generic_function=$(name)))    
        end
    end
end

function class_of(inst::Instance)
    return getfield(inst, :slots)[:instance_of]
end

# Gets the class precedence list with BFS
function compute_cpl(class::Instance)
    visited = []
    queue = [class]
    push!(visited, class)
    while !isempty(queue)
        node = queue[1]
        deleteat!(queue, 1)
        neighbors = getfield(node, :slots)[:direct_superclasses]
        for neighbor in neighbors
            if !(neighbor in visited)
                push!(queue, neighbor)
                push!(visited, neighbor)
            end
        end
    end
    return visited
end

function is_more_specific(method1::Instance, method2::Instance, args)
    for i in eachindex(args)
        class1 = method1.specializers[i].second
        class2 = method2.specializers[i].second
        if  class1 != class2
            actual_class = args[i]
            precedence_list = compute_cpl(actual_class)
            return findfirst(x -> x == class1, precedence_list) < findfirst(x -> x == class2, precedence_list)
        end
    end
    return true
end

function find_applicable_methods(methods::Array, args...)
    applicable_methods = []
    for method in methods
        applicable = true
        for i in eachindex(args)
            cpl = compute_cpl(args[i])
            class = method.specializers[i].second
            if !(class in cpl)
                applicable = false
                break
            end
        end
        if applicable
            push!(applicable_methods, method)
        end
	end
	return sort(applicable_methods, lt=(x,y)->is_more_specific(x, y, args))
end

@defclass(A, [], [])
@defclass(B, [], [])
@defclass(C, [], [])
@defclass(D, [A, B], [])
@defclass(E, [A, C], [])
@defclass(F, [D, E], [])

for x in compute_cpl(F)
    println(getfield(x, :slots)[:name])
end