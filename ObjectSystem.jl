# macro defclass(name, superclasses, slots)
#     superclasses = isempty(collect(superclasses)) ? [:Any] : collect(superclasses)

#     dump(superclasses)

#     quote
#         struct $name <: $(collect(superclasses))
#             $(Symbol(collect(slots))) # define the first slot
#         end
#     end

# end

# @defclass(Person, [], [name, age, profession])

# p = Person("John Doe", 30, "Software Engineer")

# println(p.name)
# println(p.age)

function new(class, args...)
    class = instance(class)
    if class == Nothing
        error("Cannot instantiate Nothing")
    end
end
 .
