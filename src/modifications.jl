"""
    struct UnsupportedConstraintModification{F<:AbstractFunction, S<:AbstractSet,
                                             C<:AbstractFunctionModification} <: UnsupportedError
        change::C
        message::String
    end

An error indicating that constraints of type `F`-in-`S` do not support the
constraint modification `change`.
"""
struct UnsupportedConstraintModification{F<:AbstractFunction, S<:AbstractSet,
                                         C<:AbstractFunctionModification} <: UnsupportedError
    change::C
    message::String
end
function UnsupportedConstraintModification{F, S}(change::AbstractFunctionModification) where {F<:AbstractFunction, S<:AbstractSet}
    UnsupportedConstraintModification{F, S, typeof(change)}(change, "")
end

operation_name(err::UnsupportedConstraintModification{F, S}) where {F, S} = "Modifying `$F`-in-`$S` constraints with $(err.change)"

"""
    struct UnsupportedObjectiveModification{C<:AbstractFunctionModification} <: UnsupportedError
        change::C
        message::String
    end

An error indicating that the objective function does not support the constraint
modification `change`.
"""
struct UnsupportedObjectiveModification{C<:AbstractFunctionModification} <: UnsupportedError
    change::C
    message::String
end

operation_name(err::UnsupportedObjectiveModification) = "Modifying the objective function with $(err.change)"

"""
## Constraint Function

    modify!(model::ModelLike, ci::ConstraintIndex, change::AbstractFunctionModification)

Apply the modification specified by `change` to the function of constraint `ci`.

An [`UnsupportedConstraintModification`](@ref) error is thrown if modifying
constraints is not supported by the model `model`.

### Examples

```julia
modify!(model, ci, ScalarConstantChange(10.0))
```

## Objective Function

    modify!(model::ModelLike, ::ObjectiveFunction, change::AbstractFunctionModification)

Apply the modification specified by `change` to the objective function of
`model`. To change the function completely, call `set!` instead.

An [`UnsupportedObjectiveModification`](@ref) error is thrown if modifying
objectives is not supported by the model `model`.

### Examples

```julia
modify!(model, ObjectiveFunction{ScalarAffineFunction{Float64}}(), ScalarConstantChange(10.0))
```
"""
function modify! end

function modify!(model::ModelLike, ci::ConstraintIndex{F, S},
                 change::AbstractFunctionModification) where {F, S}
    throw(UnsupportedConstraintModification{F, S}(change))
end

function modify!(model::ModelLike, ::ObjectiveFunction,
                 change::AbstractFunctionModification)
    throw(UnsupportedObjectiveModification(change))
end
