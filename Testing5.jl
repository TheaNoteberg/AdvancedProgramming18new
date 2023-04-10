mutable struct Instance
    slots::Dict{Symbol, Any}
end

Class = Instance(Dict{Symbol, Any}())
Class.slots[:name] = :Class
Class.slots[:instance_of] = Class
Class.slots[:direct_slots] = [:name, :direct_superclasses, :slots, :slots_init_values, :direct_slots, :direct_slots_init_values, :cpl, :instance_of]
Class.slots[:slots] = [:name, :direct_superclasses, :slots, :slots_init_values, :direct_slots, :direct_slots_init_values, :cpl, :instance_of]

Top = Instance(Dict{Symbol, Any}())
Top.slots[:name] = :Top
Top.slots[:instance_of] = Class
Top.slots[:direct_superclasses] = []
Top.slots[:cpl] = [Top]
Top.slots[:slots] = []
Top.slots[:direct_slots] = []

Object = Instance(Dict{Symbol, Any}())
Object.slots[:name] = :Object
Object.slots[:instance_of] = Class
Object.slots[:slots] = []
Object.slots[:direct_slots] = []

Class.slots[:direct_superclasses] = [Object]
Object.slots[:direct_superclasses] = [Top]
Class.slots[:cpl] = [Class, Top]
Object.slots[:cpl] = [Object, Top]

function Base.getproperty(instance::Instance, get::Symbol)
    all_slots = getfield(instance,:slots)
    if haskey(all_slots, get)
        if !isnothing(all_slots[get])
            return all_slots[get]
        else
            error("ERROR: Slot $(get) is unbound\n...")
        end
    else
        error("ERROR: Slot $(get) is missing\n...")
    end
end

function Base.setproperty!(instance::Instance, set::Symbol, val::Any)
    getfield(instance,:slots)[set] = val
end

function new(class; kwargs...)
    slots = Dict{Symbol, Any}(:instance_of => class)
    for (key, val) in kwargs
        slots[key] = val
    end
    Instance(slots)
end

GenericFunction = new(Class, name=:GenericFunction, direct_superclasses=[Object], direct_slots=[:name, :methods, :number_of_args, :instance_of, :current_args, :current_methods], slots=[:name, :methods, :number_of_args, :instance_of, :current_args, :current_methods], current_gen_fun_being_called=[])
GenericFunction.cpl = [GenericFunction, Object, Top]
MultiMethod = new(Class, name=:MultiMethod, direct_superclasses=[Object], direct_slots=[:name, :specializers, :procedure, :generic_function], slots=[:name, :specializers, :procedure, :generic_function, :instance_of])
MultiMethod.cpl = [MultiMethod, Object, Top]
macro defgeneric(x)
    if x.head==:call
        name = x.args[1]
        args = x.args[2:end]
        quote
            $(esc(name)) = new(GenericFunction, name=$(esc(QuoteNode(name))), methods=[], number_of_args =$(length(args)), current_args=[], current_methods=[])
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
            if (param.args[2] == :Int)
                push!(specializers, :_Int64)
            elseif (param.args[2] == :String)
                push!(specializers, :_String)
            else
                push!(specializers, param.args[2])
            end
        end
    end
    name_symbol = function_head.args[1]
    name = name_symbol
    procedure = x.args[2].args
    quote
        !@isdefined($(name_symbol)) && @defgeneric $(name)($(args...))
        if typeof($(name_symbol)) != Instance || getfield($(name_symbol), :slots)[:instance_of] != GenericFunction
            error("ERROR: $(name_symbol) is not a generic function\n...")
        end
        slots = getfield($(name), :slots)
        function lambda($(args...))
            $((procedure)...)
        end
        if getfield($(name), :slots)[:number_of_args] == length($specializers)
            pushfirst!(slots[:methods], new(MultiMethod, name=missing, specializers=[$(map(esc, specializers)...)], procedure=lambda, generic_function=$(name)))
        end
    end
end

function is_more_specific(method1::Instance, method2::Instance, args)
    for i in eachindex(args)
        class1 = method1.specializers[i]
        class2 = method2.specializers[i]
        if  class1 != class2
            arg_class = class_of(args[i])
            return findfirst(x -> x == class1, arg_class.cpl) < findfirst(x -> x == class2, arg_class.cpl)
        end
    end
    true
end

function find_applicable_methods(methods::Array, args...)
    applicable_methods = []
    for method in methods
        applicable = true
        for i in eachindex(args)
            cpl = class_cpl(class_of(args[i]))
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
	sort(applicable_methods, lt=(x,y)->is_more_specific(x, y, args))
end
function (inst::Instance)(args...)
    slots = getfield(inst, :slots)
    if slots[:instance_of] === GenericFunction
        applicable_methods = find_applicable_methods(slots[:methods], args...)
        if length(applicable_methods) == 0
            return no_applicable_method(inst, args)
        end
        current_gen_fun_being_called = getfield(GenericFunction, :slots)[:current_gen_fun_being_called]
        push!(current_gen_fun_being_called, inst)
        getfield(inst, :slots)[:current_args] = args
        getfield(inst, :slots)[:current_methods] = applicable_methods
        res = call_next_method()
        pop!(current_gen_fun_being_called)
        return res
    else
        error("ERROR: $(inst) is not a generic function\n...")
    end
end

@defmethod no_applicable_method(gf::GenericFunction, args) = error("ERROR: No applicable method for function $(gf) with arguments $(args)\n...")

function call_next_method()
    gen_fun_being_called = getfield(GenericFunction, :slots)[:current_gen_fun_being_called][end]
    args = getfield(gen_fun_being_called, :slots)[:current_args]
    methods = getfield(gen_fun_being_called, :slots)[:current_methods]
    if length(methods) == 0
        return no_applicable_method(gen_fun_being_called, args)
    end
    next_method = popfirst!(methods)
    procedure = next_method.procedure
    procedure(args...)
end

@defmethod compute_cpl(class::Class) = begin
    visited = [class]
    queue = [class]
    while !isempty(queue)
        node = popfirst!(queue)
        neighbors = getfield(node, :slots)[:direct_superclasses]
        for neighbor in neighbors
            if !(neighbor in visited)
                push!(queue, neighbor)
                push!(visited, neighbor)
            end
        end
    end
    visited
end

###
### Get-Functions
###
function class_of(inst::Any)
    if typeof(inst) == Instance
        return getfield(inst, :slots)[:instance_of]
    end
    if typeof(inst) == Int
        return _Int64
    end
    if typeof(inst) == String
        return _String
    end
    Top
end

function class_name(inst::Instance)
    getfield(inst, :slots)[:name]
end

function class_direct_slots(inst::Instance)
    getfield(inst, :slots)[:direct_slots]
end

function class_direct_slots_init_values(inst::Instance)
    getfield(inst, :slots)[:direct_slots_init_values]
end

function class_slots(inst::Instance)
    getfield(inst, :slots)[:slots]
end

function class_direct_superclasses(inst::Instance)
    getfield(inst, :slots)[:direct_superclasses]
end

function class_cpl(inst::Instance)
    getfield(inst, :slots)[:cpl]
end

function generic_methods(inst::Instance)
    getfield(inst, :slots)[:methods]
end

function method_specializers(inst::Instance)
    getfield(inst, :slots)[:specializers]
end

@defmethod compute_slots(class::Class) = vcat(map(class_direct_slots, class_cpl(class))...)
@defmethod compute_slots_init_values(class::Class) = begin
    init_values = Dict{Symbol, Any}()
    for cpl_class in class_cpl(class)
        if (haskey(getfield(cpl_class, :slots), :direct_slots_init_values))
            init_values = merge!(init_values, class_direct_slots_init_values(cpl_class))
        end
    end
    init_values
end

@defmethod compute_getter_and_setter(class::Class, slot_name, idx) = begin
    (
        (inst) -> begin
            getfield(inst, :slots)[slot_name]
        end,
        (inst, value) -> begin
            getfield(inst, :slots)[slot_name] = value
        end
    )
end

function set_getters_and_setters(inst)
    getters = Dict()
    setters = Dict()
    for slot in [inst.slots..., :instance_of]
        (getter, setter) = compute_getter_and_setter(inst, slot, missing)
        getters[slot] = getter
        setters[slot] = setter
    end
    getfield(inst, :slots)[:getters] = getters
    getfield(inst, :slots)[:setters] = setters
end
set_getters_and_setters(Class)
set_getters_and_setters(Top)
set_getters_and_setters(Object)
set_getters_and_setters(GenericFunction)
set_getters_and_setters(MultiMethod)

Base.getproperty(inst::Instance, slot_name::Symbol) = begin
    instance_of = getfield(inst, :slots)[:instance_of]
    getfield(instance_of, :slots)[:getters][slot_name](inst)
end

Base.setproperty!(inst::Instance, slot_name::Symbol, val) = begin
    instance_of = getfield(inst, :slots)[:instance_of]
    getfield(instance_of, :slots)[:setters][slot_name](inst, val)
end

@defmethod allocate_instance(class::Class) = begin
    inst = Instance(Dict{Symbol, Any}(:instance_of => class))
    slots = getfield(inst, :slots)
    if haskey(getfield(class, :slots), :slots_init_values)
        slots_from_class = class.slots
        slots_init_values = class.slots_init_values
        for i in eachindex(slots_from_class)
            if (haskey(slots_init_values, slots_from_class[i]))
                slots[slots_from_class[i]] = slots_init_values[slots_from_class[i]]
            end
        end
    end
    inst    
end

@defmethod initialize(object::Object, initargs) = begin
    for (first, second) in initargs
        setproperty!(object, first, second)
    end
end
@defmethod initialize(class::Class, initargs) = begin
    for (first, second) in initargs
        setproperty!(class, first, second)
    end
    if isempty(class.direct_superclasses)
        setproperty!(class, :direct_superclasses, [Object])
    end
    setproperty!(class, :cpl, compute_cpl(class))
    setproperty!(class, :slots, compute_slots(class))

    init_values = compute_slots_init_values(class)
    if !isempty(init_values)
        setproperty!(class, :slots_init_values, init_values)
    end
    set_getters_and_setters(class)
end
@defmethod initialize(generic::GenericFunction, initargs) = begin
    for (first, second) in initargs
        setproperty!(generic, first, second)
    end
end
@defmethod initialize(method::MultiMethod, initargs) = begin
    for (first, second) in initargs
        setproperty!(method, first, second)
    end
end

new(class; initargs...) =
    let instance = allocate_instance(class)
        initialize(instance, initargs)
        instance
    end

macro defclass(classname, superclasses, slots, metaClass=missing)
    if ismissing(metaClass)
        metaClass = :Class
    else
        metaClass = metaClass.args[2]
    end
    direct_slot_names = []
    direct_init_values = []
    methods_to_define = []
    for slot in slots.args
        if isa(slot, Expr) && slot.head != :(=)
            slot = convert(Array, slot.args)
        else
            slot = [slot]
        end
        slot_name = slot[1]
        if isa(slot_name, Expr)
            push!(direct_init_values, slot_name.args[2])
            slot_name = slot_name.args[1]
        else
            push!(direct_init_values, missing)
        end
        push!(direct_slot_names, slot_name)
        for j in eachindex(slot[2:end])
            i = j+1
            if slot[i].args[1] == :reader
                push!(methods_to_define, :(@defmethod $(slot[i].args[2])(o::$(classname)) = o.$(slot_name)))
            end
            if slot[i].args[1] == :writer
                push!(methods_to_define, :(@defmethod $(slot[i].args[2])(o::$(classname), v) = o.$(slot_name) = v))
            end
            if slot[i].args[1] == :initform
                direct_init_values[end] = slot[i].args[2]
            end
        end
    end
    quote
        init_values = Dict{Symbol, Any}()
        for i in eachindex($(esc.(direct_slot_names)))
            init_values[$(direct_slot_names)[i]] = $(direct_init_values)[i]
        end

        $(esc(classname)) = new($metaClass, name=$(QuoteNode(classname)), direct_superclasses=$superclasses, direct_slots_init_values=init_values, direct_slots=$(map(x->x, direct_slot_names)))
        if !isempty($methods_to_define)
            $(esc.(methods_to_define)...)
        end
            
    end
end
@defclass(BuiltInClass, [Class], [])
@defclass(_Int64, [], [], metaClass=BuiltInClass)
@defclass(_String, [], [], metaClass=BuiltInClass)

@defgeneric print_object(obj, io)
@defmethod print_object(obj::Object, io) =
print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>")
@defmethod print_object(class::Class, io) =
print(io, "<$(class_name(class_of(class))) $(class_name(class))>")
Base.show(io::IO, inst::Instance) = print_object(inst, io)
# TODO add print_object for generic_methods(draw)
#=Should look like this: [<MultiMethod draw(ColorMixin, Device)>, <MultiMethod draw(Circle, Printer)>,
<MultiMethod draw(Line, Printer)>, <MultiMethod draw(Circle, Screen)>,
<MultiMethod draw(Line, Screen)>]=#