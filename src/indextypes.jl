# Index types

"""
    ConstraintIndex{F,S}

A type-safe wrapper for `Int64` for use in referencing `F`-in-`S` constraints in
a model.
The parameter `F` is the type of the function in the constraint, and the
parameter `S` is the type of set in the constraint. To allow for deletion,
indices need not be consecutive. Indices within a constraint type (i.e. `F`-in-`S`)
must be unique, but non-unique indices across different constraint types are allowed.
"""
struct ConstraintIndex{F,S}
    value::Int64
end

"""
    VariableIndex

A type-safe wrapper for `Int64` for use in referencing variables in a model.
To allow for deletion, indices need not be consecutive.
"""
struct VariableIndex
    value::Int64
end

const Index = Union{ConstraintIndex,VariableIndex}

"""
    struct InvalidIndex{IndexType<:Index} <: Exception
        index::IndexType
    end

An error indicating that the index `index` is invalid.
"""
struct InvalidIndex{IndexType<:Index} <: Exception
    index::IndexType
end

function Base.showerror(io::IO, err::InvalidIndex)
    print("The index $(err.index) is invalid. Note that an index becomes invalid after it has been deleted.")
end

"""
    isvalid(model::ModelLike, index::Index)::Bool

Return a `Bool` indicating whether this index refers to a valid object in the model `model`.
"""
isvalid(model::ModelLike, ref::Index) = false

"""
    struct CannotDelete{IndexType <: Index} <: CannotTryResetError
        index::IndexType
        message::String
    end

An error indicating that the index `index` cannot be deleted.
"""
struct CannotDelete{IndexType <: Index} <: CannotTryResetError
    index::IndexType
    message::String
end
CannotDelete(index::Index) = CannotDelete(index, "")

function operation_name(err::CannotDelete)
    return "Deleting the index $(err.index)"
end

"""
    delete!(model::ModelLike, index::Index)

Delete the referenced object from the model.
"""
Base.delete!(model::ModelLike, index::Index) = throw(CannotDelete(index))

"""
    delete!{R}(model::ModelLike, indices::Vector{R<:Index})

Delete the referenced objects in the vector `indices` from the model.
It may be assumed that `R` is a concrete type.
"""
function Base.delete!(model::ModelLike, indices::Vector{<:Index})
    for index in indices
        Base.delete!(model, index)
    end
end
