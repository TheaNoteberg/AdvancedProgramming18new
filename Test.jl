# Define the macro
# macro defclass(args...)
#     name = args[1]
#     superclasses = length(args[2].args) > 0 ? args[2].args : [:Any]
#     slots = args[end]

#     quote
#         struct $name <: $(superclasses...)
#             $(Symbol.(slots)) # define the slots
#         end
#     end
# end

# # Define a class using the macro
# @defclass(Person, [], [name, age, profession])

# # Create an instance of the class
# p = Person("John Doe", 30, "Engineer")

# # Test that the instance has the specified slots
# println(p.name)        # Output: John Doe
# println(p.age)         # Output: 30
# println(p.profession)  # Output: Engineer
