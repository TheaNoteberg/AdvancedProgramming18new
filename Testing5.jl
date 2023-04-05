mutable struct Instance
    slots::Dict{Symbol, Any}
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

Class = Instance(Dict{Symbol, Any}())
Class.slots[:name] = :Class
Class.slots[:instance_of] = Class
Class.slots[:direct_slots] = [:name, :direct_superclasses, :direct_slots]

Top = Instance(Dict{Symbol, Any}())
Top.slots[:name] = :Top
Top.slots[:instance_of] = Class
Top.slots[:direct_superclasses] = []
Top.slots[:cpl] = [Top]

Object = Instance(Dict{Symbol, Any}())
Object.slots[:name] = :Object
Object.slots[:instance_of] = Class

Class.slots[:direct_superclasses] = [Object]
Object.slots[:direct_superclasses] = [Top]
Class.slots[:cpl] = compute_cpl(Class)
Object.slots[:cpl] = compute_cpl(Object)

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
    println("enter new")
    slots = Dict{Symbol, Any}()
    instance = Instance(slots)
    slotnames = []
    if haskey(getfield(class, :slots), :cpl)
        superclasses = getfield(class, :slots)[:cpl]
        for superclass in superclasses
            if haskey(getfield(superclass, :slots), :direct_slots)
                println("direct slots ", superclass.direct_slots)
                for super_slot in superclass.direct_slots
                    if !isa(super_slot, Symbol)
                        slots[super_slot[1]] = super_slot[2]
                        push!(slotnames, super_slot[1])
                    else
                        slots[super_slot] = missing
                        push!(slotnames, super_slot)
                    end                    
                end
            end
        end        
    end
    for (first, second) in kwargs
        if first in slotnames
            slots[first] = second
            if first == :direct_superclasses
                if isempty(second)
                    slots[first] = [Object]
                end
                slots[:cpl] = compute_cpl(instance)
            end
        else
            error("ERROR: Slot $(first) is missing\n...")
        end
    end
    slots[:instance_of] = class
    
    return instance
end

GenericFunction = new(Class, name=:GenericFunction, direct_superclasses=[Object], direct_slots=[:name, :methods, :number_of_args])
MultiMethod = new(Class, name=:MultiMethod, direct_superclasses=[Object], direct_slots=[:name, :specializers, :procedure, :generic_function])
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
    args = []
    specializers = []
    function_head = x.args[1]
    for i in 2:length(function_head.args)
        param = function_head.args[i]
        if isa(param, Symbol)
            push!(args, param)
            push!(specializers, :Top)            
        else
            push!(args, param.args[1])
            push!(specializers, param.args[2])
        end
    end
    name_symbol = function_head.args[1]
    name = name_symbol
    procedure = x.args[2].args[2]

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
            push!(slots[:methods], new(MultiMethod, name=missing, specializers=[$(map(esc, specializers)...)], procedure=lambda, generic_function=$(name)))    
        end
    end
end

@defmethod no_applicable_method(gf::GenericFunction, args) = error("ERROR: No applicable method for function $(gf) with arguments $(args)\n...")


macro defclass(classname, superclasses, slots, metaClass=Class)
    init_slots = Vector{Pair}()
    methods_to_define = []
    for slot in slots.args
        if isa(slot, Symbol)
            slot = [slot]
        else
            slot = convert(Array, slot.args)
        end
        slot_name = slot[1]
        if isa(slot_name, Symbol)
            slot_pair = Pair(slot_name, missing)
        else
            slot_pair = Pair(slot_name.args[1], slot_name.args[2])
            slot_name = slot_name.args[1]
        end
        for j in eachindex(slot[2:end])
            i = j+1
            if slot[i].args[1] == :reader
                push!(methods_to_define, :(@defmethod $(slot[i].args[2])(o::$(classname)) = o.$(slot_name)))            
            end
            if slot[i].args[1] == :writer
                push!(methods_to_define, :(@defmethod $(slot[i].args[2])(o::$(classname), v) = o.$(slot_name) = v))
            end
            if slot[i].args[1] == :initform
                slot_pair = Pair(slot_name, slot[i].args[2])
            end
        end
        push!(init_slots, slot_pair)
    end
    quote        
        $(esc(classname)) = new($metaClass, name=$(QuoteNode(classname)), direct_superclasses=$superclasses, direct_slots=$(map(x->x, init_slots)))
        if !isempty($methods_to_define)
            $(esc.(methods_to_define)...)
        end
            
    end
end

@defclass(ComplexNumber, [], [[real=3, reader=get_real], [imag, initform=2, writer=set_imag!]])
ComplexNumber.direct_slots
c1 = new(ComplexNumber)
c1.real
c1.imag
set_imag!(c1, 5)
c1.imag
c2 = new(ComplexNumber, real=3)
c2.real
c2.imag

@defclass(BuiltInClass, [Class], [])
@defclass(_Int64, [], [], metaClass=BuiltInClass)
@defclass(_String, [], [], metaClass=BuiltInClass)

function (inst::Instance)(args...)
    slots = getfield(inst, :slots)
    if slots[:instance_of] === GenericFunction        
        applicable_methods = find_applicable_methods(slots[:methods], args...)

        if length(applicable_methods) == 0
            return no_applicable_method(inst, args...)
        end
        procedure = applicable_methods[1].procedure
        return procedure(args...)
    else
        error("ERROR: $(inst) is not a generic function\n...")
    end
end

function class_of(inst::Instance)
    return getfield(inst, :slots)[:instance_of]
end

function class_of(inst::Int)
    return _Int64
end

function class_of(inst::String)
    return _String
end

function class_of(inst::Any)
    return Top
end


 
function is_more_specific(method1::Instance, method2::Instance, args)
    for i in eachindex(args)
        class1 = method1.specializers[i]
        class2 = method2.specializers[i]
        if  class1 != class2
            actual_class = class_of(args[i])
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
            cpl = compute_cpl(class_of(args[i]))
            class = method.specializers[i]
            
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

c1 = new(ComplexNumber, real=3, imag=2)
c2 = new(ComplexNumber, real=7, imag=1)

@defgeneric add(a, b)
@defmethod add(a::ComplexNumber, b) =
new(ComplexNumber, real=(a.real + b.real), imag=(a.imag + b.imag))

c3 = add(c1, c2)
c3.real

@defgeneric print_object(obj, io)
@defmethod print_object(obj::Object, io) =
print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>")
@defmethod print_object(c::ComplexNumber, io) =
print(io, "$(c.real)$(c.imag < 0 ? "-" : "+")$(abs(c.imag))i")
Base.show(io::IO, inst::Instance) = print_object(inst, io)