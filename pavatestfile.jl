using Test

include("JOS.jl") # the sourcefile

# Test the ComplexNumber class (2.1)
@defclass(ComplexNumber, [], [real, imag])

# Test creating instances of a class (2.2)
c1 = new(ComplexNumber, real=2, imag=1)

# Test slot access (2.3)
getproperty(c1, :real) # 2
c1.real # 2
setproperty!(c1, :imag, -1) # -1
c1.imag += 3 # 2

# Define a simple example instance with a "slots" field
struct ExampleInstance
    slots::Dict{Symbol, Any}
end

# Define the property access methods
function Base.getproperty(instance::ExampleInstance, get::Symbol)
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

function Base.setproperty!(instance::ExampleInstance, set::Symbol, val::Any)
    all_slots = getfield(instance,:slots)
    all_slots[set] = val
end

# Create an instance of the example instance and set a property
ex = ExampleInstance(Dict(:foo => 42))
setproperty!(ex, :bar, "hello")

# Test getting properties
println(getproperty(ex, :foo))  # should print 42
println(getproperty(ex, :bar))  # should print "hello"

# Try to get a non-existent property
try
    println(getproperty(ex, :baz))
catch e
    println(e)
end

# Try to set a property to nothing
setproperty!(ex, :qux, nothing)
try
    println(getproperty(ex, :qux))
catch e
    println(e)
end

# test generic functions and methods (2.4)
# Define the necessary types
abstract type AbstractInstance end

struct MyInstance <: AbstractInstance
    slots::Dict{Symbol, Any}
end

struct MyClass <: AbstractInstance
    slots::Tuple{Symbol,Symbol}
    slots_init_values::Dict{Symbol,Any}
end

# Define the new method
function new(class::MyClass; kwargs...)
    slots = Dict{Symbol, Any}()
    instance = MyInstance(slots)
    if haskey(getfield(class, :slots), :slots_init_values)
        slots_from_class = class.slots
        slots_init_values = class.slots_init_values
        for i in eachindex(slots_from_class)
            if haskey(slots_init_values, slots_from_class[i])
                slots[slots_from_class[i]] = slots_init_values[slots_from_class[i]]
            end
        end
    end
    for (key, val) in kwargs
        slots[key] = val
    end
    slots[:instance_of] = class
    instance
end

# Test generic fuctions and methods (2.4)
@defgeneric add(a, b)

@defmethod add(a::ComplexNumber, b::ComplexNumber) =
  new(ComplexNumber, real=(a.real + b.real), imag=(a.imag + b.imag))

# Define methods for the generic function
@defmethod add(a::Int, b::Int) = a + b
@defmethod add(a::Float64, b::Float64) = a + b
@defmethod add(a::String, b::String) = string(a, b)

# Test the generic function with different inputs
@test add(1, 2) == 3
@test add(3.5, 2.1) == 5.6
@test add("hello", "world") == "helloworld"

# Test Pre-defined Generic Functions and Methods (2.5)
@defgeneric print_object(obj, io)

c2 = new(ComplexNumber, real=3, imag=4)

@defmethod print_object(obj::Object, io) =
  print(io, "<$(class_name(class_of(obj))) $(string(objectid(obj), base=62))>")

@defmethod print_object(c::ComplexNumber, io) =
  print(io, "$(c.real)$(c.imag < 0 ? "-" : "+")$(abs(c.imag))i")

c1 #2+2i
c2 #3+4i
add(c1, c2) #5+6i

# Test MetaObjects (2.6)
class_of(c1) # ComplexNumber
ComplexNumber.direct_slots #:real, :imag
class_of(class_of(c1)) # Class
class_of(class_of(class_of(c1))) # Class
Class.slots # :name, :direct_superclasses, :direct_slots, ... , cpl, instance_of (8-element vector)
ComplexNumber.name # :ComplexNumber
ComplexNumber.direct_superclasses == [Object] # true
add # <GenericFunction add with 1 methods>
class_of(add) === GenericFunction # true
GenericFunction.slots # :name, :methods, ... , current_args, current_methods (6 element vector)
add.methods[1] #<MultiMethod add(ComplexNumber, ComplexNumber)>
add.methods[1].generic_function === add # true

# Test Class Options (2.7)
@defclass(Person, [],
  [[name, reader=get_name, writer=set_name!],
   [age, reader=get_age, writer=set_age!, initform=0],
   [friend, reader=get_friend, writer=set_friend!]],
   metaclass=UndoableClass)

Person #<UndoableClass Person>
class_of(Person) #<Class UndoableClass>
class_of(class_of(Person)) #<Class Class>

# Test Readers and Writers (2.8)
@defmethod get_name(o::Person) = o.name
@defmethod set_name!(o::Person, v) = o.name = v
@defmethod get_age(o::Person) = o.age
@defmethod set_age!(o::Person, v) = o.age = v
@defmethod get_friend(o::Person) = o.friend
@defmethod set_friend!(o::Person, v) = o.friend = v

get_age(new(Person)) #should be 0
get_name(new(Person)) # should be 'missing'

# Test Generic Function Calls (2.9)


# Test Multiple Dispatch (2.10)
@defclass(Shape, [], [])
@defclass(Device, [], [])
@defgeneric draw(shape, device)
@defclass(Line, [Shape], [from, to])
@defclass(Circle, [Shape], [center, radius])
@defclass(Screen, [Device], [])
@defclass(Printer, [Device], [])
@defmethod draw(shape::Line, device::Screen) = println("Drawing a Line on Screen")
@defmethod draw(shape::Circle, device::Screen) = println("Drawing a Circle on Screen")
@defmethod draw(shape::Line, device::Printer) = println("Drawing a Line on Printer")
@defmethod draw(shape::Circle, device::Printer) = println("Drawing a Circle on Printer")
let devices = [new(Screen), new(Printer)],
    shapes = [new(Line), new(Circle)]
  for device in devices
    for shape in shapes
      draw(shape, device)
end end
end
# should be this:
# Drawing a Line on Screen
# Drawing a Circle on Screen
# Drawing a Line on Printer
# Drawing a Circle on Printer

# Test Multiple Inheritance (2.11)
@defclass(ColorMixin, [],
  [[color, reader=get_color, writer=set_color!]])
@defmethod draw(s::ColorMixin, d::Device) =
  let previous_color = get_device_color(d)
    set_device_color!(d, get_color(s))
    call_next_method()
    set_device_color!(d, previous_color)
end
@defclass(ColoredLine, [ColorMixin, Line], [])
@defclass(ColoredCircle, [ColorMixin, Circle], [])
@defclass(ColoredPrinter, [Printer],
  [[ink=:black, reader=get_device_color, writer=_set_device_color!]])
@defmethod set_device_color!(d::ColoredPrinter, color) = begin
  println("Changing printer ink color to $color")
  _set_device_color!(d, color)
end
let shapes = [new(Line), new(ColoredCircle, color=:red), new(ColoredLine, color=:blue)],
    printer = new(ColoredPrinter, ink=:black)
  for shape in shapes
    draw(shape, printer)
end end
# should be this:
# Drawing a Line on Printer
# Changing printer ink color to red
# Drawing a Circle on Printer
# Changing printer ink color to black
# Changing printer ink color to blue
# Drawing a Line on Printer
# Changing printer ink color to black

# Test Class Hierarchy (2.12)
ColoredCircle.direct_superclasses # should be [<Class ColorMixin>, <Class Circle>]
ans[1].direct_superclasses # [<Class Object>]
ans[1].direct_superclasses # [<Class Top>]
ans[1].direct_superclasses # []

# Test Class Precedence List (2.13)
@defclass(A, [], [])
@defclass(B, [], [])
@defclass(C, [], [])
@defclass(D, [A, B], [])
@defclass(E, [A, C], [])
@defclass(F, [D, E], [])

compute_cpl(F) # [<Class F>, <Class D>, <Class E>, <Class A>, <Class B>, <Class C>, <Class Object>, <Class Top>]

# Test Built-In Classes (2.14)
class_of(1) # <BuiltInClass _Int64>
class_of("Foo") # <BuiltInClass _String>

@defmethod add(a::_Int64, b::_Int64) = a + b
@defmethod add(a::_String, b::_String) = a * b

add(1, 3) # should be 4
add("Foo", "Bar") # should be "FooBar"

# Test Introspection (2.15)
class_name(Circle) # :Circle
class_direct_slots(Circle) # [:center, :radius]
class_direct_slots(ColoredCircle) # []
class_slots(ColoredCircle) # [:color, :center, :radius]
class_direct_superclasses(ColoredCircle) # [<Class ColorMixin>, <Class Circle>]
class_cpl(ColoredCircle) # [<Class ColoredCircle>, <Class ColorMixin>, <Class Circle>, <Class Object>, <Class Shape>, <Class Top>]
generic_methods(draw) # [<MultiMethod draw(ColorMixin, Device)>, <MultiMethod draw(Circle, Printer)>,<MultiMethod draw(Line, Printer)>, <MultiMethod draw(Circle, Screen)>,<MultiMethod draw(Line, Screen)>]
method_specializers(generic_methods(draw)[1]) # [<Class ColorMixin>, <Class Device>]

# Test Meta-Object Protocols (2.16)
# Class Instantiation Protocol (2.16.1)
new(class; initargs...) =
  let instance = allocate_instance(class)
    initialize(instance, initargs)
instance
end

# The Compute Slots Protocol (2.16.2)
@defmethod compute_slots(class::Class) =
  vcat(map(class_direct_slots, class_cpl(class))...)

@defclass(Foo, [], [a=1, b=2]) # <Class Foo>
@defclass(Bar, [], [b=3, c=4]) # <Class Bar>
@defclass(FooBar, [Foo, Bar], [a=5, d=6]) # <Class FooBar>
class_slots(FooBar) # [:a, :d, :a, :b, :b, :c]
foobar1 = new(FooBar) # <FooBar xxxxxxxxxx>
foobar1.a #1
foobar1.b #3
foobar1.c #4
foobar1.d #6

@defclass(AvoidCollisionsClass, [Class], [])
@defmethod compute_slots(class::AvoidCollisionsClass) =
  let slots = call_next_method(),
      duplicates = symdiff(slots, unique(slots))
    isempty(duplicates) ?
slots :
      error("Multiple occurrences of slots: $(join(map(string, duplicates), ", "))")
  end

@defclass(FooBar2, [Foo, Bar], [a=5, d=6], metaclass=AvoidCollisionsClass) # ERROR: Multiple occurrences of slots: a, b ?

# Slot Access Protocol (2.16.3)
undo_trail = []
store_previous(object, slot, value) = push!(undo_trail, (object, slot, value))
current_state() = length(undo_trail)
restore_state(state) =
  while length(undo_trail) != state
    restore(pop!(undo_trail)...)
end
save_previous_value = true
restore(object, slot, value) =
  let previous_save_previous_value = save_previous_value
    global save_previous_value = false
    try
      setproperty!(object, slot, value)
    finally
      global save_previous_value = previous_save_previous_value
end end

@defclass(UndoableClass, [Class], [])
@defmethod compute_getter_and_setter(class::UndoableClass, slot, idx) =
  let (getter, setter) = call_next_method()
    (getter,
     (o, v)->begin
     if save_previous_value
        store_previous(o, slot, getter(o))
    end
      setter(o, v)
end)
end

@defclass(Person, [],
  [name, age, friend],
  metaclass=UndoableClass)
@defmethod print_object(p::Person, io) =
  print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]")

p0 = new(Person, name="John", age=21)
p1 = new(Person, name="Paul", age=23)
#Paul has a friend named John
p1.friend = p0
println(p1) #[Paul,23 with friend [John,21]]
state0 = current_state()
#32 years later, John changed his name to 'Louis' and got a friend
p0.age = 53
p1.age = 55
p0.name = "Louis"
p0.friend = new(Person, name="Mary", age=19)
println(p1) #[Paul,55 with friend [Louis,53 with friend [Mary,19]]]
state1 = current_state()
#15 years later, John (hum, I mean 'Louis') died
p1.age = 70
p1.friend = missing
println(p1) #[Paul,70]
restore_state(state1)
println(p1) #[Paul,55 with friend [Louis,53 with friend [Mary,19]]]
#and even earlier
restore_state(state0)
println(p1) #[Paul,23 with friend [John,21]]

# Class Precedence List Protocol (2.16.4)
@defclass(FlavorsClass, [Class], [])
@defmethod compute_cpl(class::FlavorsClass) =
  let depth_first_cpl(class) =
        [class, foldl(vcat, map(depth_first_cpl, class_direct_superclasses(class)), init=[])...],
      base_cpl = [Object, Top]
    vcat(unique(filter(!in(base_cpl), depth_first_cpl(class))), base_cpl)
end
@defclass(A, [], [], metaclass=FlavorsClass)
@defclass(B, [], [], metaclass=FlavorsClass)
@defclass(C, [], [], metaclass=FlavorsClass)
@defclass(D, [A, B], [], metaclass=FlavorsClass)
@defclass(E, [A, C], [], metaclass=FlavorsClass)
@defclass(F, [D, E], [], metaclass=FlavorsClass)

compute_cpl(F) #[<FlavorsClass F>, <FlavorsClass D>, <FlavorsClass A>,<FlavorsClass B>, <FlavorsClass E>, <FlavorsClass C>,<Class Object>, <Class Top>]

# Multiple Meta-Class Inheritance (2.17)
@defclass(UndoableCollisionAvoidingCountingClass,[UndoableClass, AvoidCollisionsClass, CountingClass],[])
@defclass(NamedThing, [], [name]) # <Class NamedThing>
@defclass(Person, [NamedThing],
    [name, age, friend],
    metaclass=UndoableCollisionAvoidingCountingClass) # ERROR: Multiple occurrences of slots: name
@defclass(Person, [NamedThing],
    [age, friend],
    metaclass=UndoableCollisionAvoidingCountingClass) # <UndoableCollisionAvoidingCountingClass Person>
@defmethod print_object(p::Person, io) =
    print(io, "[$(p.name), $(p.age)$(ismissing(p.friend) ? "" : " with friend $(p.friend)")]") #<MultiMethod print_object(Person)>

    p0 = new(Person, name="John", age=21)
p1 = new(Person, name="Paul", age=23)
#Paul has a friend named John
p1.friend = p0
println(p1) #[Paul,23 with friend [John,21]]
state0 = current_state()
#32 years later, John changed his name to 'Louis' and got a friend
#and even earlier
restore_state(state0)
println(p1) #[Paul,23 with friend [John,21]]

Person.counter #3