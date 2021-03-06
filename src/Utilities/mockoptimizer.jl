
# An Int-valued attribute
struct MockModelAttribute <: MOI.AbstractModelAttribute
end

# An Int-valued attribute
struct MockVariableAttribute <: MOI.AbstractVariableAttribute
end

# An Int-valued attribute
struct MockConstraintAttribute <: MOI.AbstractConstraintAttribute
end

# A mock optimizer used for testing.
mutable struct MockOptimizer{MT<:MOI.ModelLike} <: MOI.AbstractOptimizer
    inner_model::MT
    attribute::Int # MockModelAttribute
    varattribute::Dict{MOI.VariableIndex,Int} # MockVariableAttribute
    conattribute::Dict{MOI.ConstraintIndex,Int} # MockConstraintAttribute
    needsallocateload::Bool # Allows to tests the Allocate-Load interface, see copy!
    canaddvar::Bool
    canaddcon::Bool # If false, the optimizer throws CannotAddConstraint
    optimize!::Function
    solved::Bool
    hasprimal::Bool
    hasdual::Bool
    terminationstatus::MOI.TerminationStatusCode
    resultcount::Int
    # Computes `ObjectiveValue` by evaluating the `ObjectiveFunction` with
    # `VariablePrimal`. See `get_fallback`.
    eval_objective_value::Bool
    objectivevalue::Float64
    objectivebound::Float64  # set this using MOI.set!(model, MOI.ObjectiveBound(), value)
    primalstatus::MOI.ResultStatusCode
    dualstatus::MOI.ResultStatusCode
    varprimal::Dict{MOI.VariableIndex,Float64}
    # Computes `ConstraintDual` of constraints with `SingleVariable` or
    # `VectorOfVariables` functions by evaluating the `ConstraintDual` of
    # constraints having the variable in the function. See `get_fallback`.
    eval_variable_constraint_dual::Bool
    condual::Dict{MOI.ConstraintIndex,Any}
end

# All user-facing indices are xor'd with this mask to produce unusual indices.
# This is good at catching bugs.
const internal_xor_mask = Int64(12345678)
xor_index(vi::VI) = VI(xor(vi.value, internal_xor_mask))
xor_index(ci::CI{F,S}) where {F,S} = CI{F,S}(xor(ci.value, internal_xor_mask))
xor_variables(f) = mapvariables(xor_index, f)

function MockOptimizer(inner_model::MOI.ModelLike; needsallocateload=false,
                       eval_objective_value=true,
                       eval_variable_constraint_dual=true)
    return MockOptimizer(inner_model,
                         0,
                         Dict{MOI.VariableIndex,Int}(),
                         Dict{MOI.ConstraintIndex,Int}(),
                         needsallocateload,
                         true,
                         true,
                         (::MockOptimizer) -> begin end,
                         false,
                         false,
                         false,
                         MOI.Success,
                         0,
                         eval_objective_value,
                         NaN,
                         NaN,
                         MOI.UnknownResultStatus,
                         MOI.UnknownResultStatus,
                         Dict{MOI.VariableIndex,Float64}(),
                         eval_variable_constraint_dual,
                         Dict{MOI.ConstraintIndex,Any}())
end

function MOI.addvariable!(mock::MockOptimizer)
    if mock.canaddvar
        return xor_index(MOI.addvariable!(mock.inner_model))
    else
        throw(MOI.CannotAddVariable())
    end
end
function MOI.addvariables!(mock::MockOptimizer, n::Int)
    if mock.canaddvar
        return xor_index.(MOI.addvariables!(mock.inner_model, n))
    else
        throw(MOI.CannotAddVariable())
    end
end
function MOI.addconstraint!(mock::MockOptimizer,
                            func::MOI.AbstractFunction,
                            set::MOI.AbstractSet)
    if mock.canaddcon
        ci = MOI.addconstraint!(mock.inner_model, xor_variables(func), set)
        return xor_index(ci)
    else
        throw(MOI.CannotAddConstraint{typeof(func), typeof(set)}())
    end
end
function MOI.optimize!(mock::MockOptimizer)
    mock.solved = true
    mock.hasprimal = true
    mock.hasdual = true
    mock.optimize!(mock)
end

MOI.supports(mock::MockOptimizer, ::Union{MOI.VariablePrimal,MockVariableAttribute}, ::Type{MOI.VariableIndex}) = true
MOI.supports(mock::MockOptimizer, attr::MOI.AbstractVariableAttribute, IdxT::Type{MOI.VariableIndex}) = MOI.supports(mock.inner_model, attr, IdxT)
MOI.supports(mock::MockOptimizer, ::Union{MOI.ConstraintDual,MockConstraintAttribute}, ::Type{<:MOI.ConstraintIndex}) = true
MOI.supports(mock::MockOptimizer, attr::MOI.AbstractConstraintAttribute, IdxT::Type{<:MOI.ConstraintIndex}) = MOI.supports(mock.inner_model, attr, IdxT)

MOI.supports(mock::MockOptimizer, ::Union{MOI.ResultCount,MOI.TerminationStatus,MOI.ObjectiveValue,MOI.PrimalStatus,MOI.DualStatus,MockModelAttribute}) = true
MOI.set!(mock::MockOptimizer, ::MOI.ResultCount, value::Integer) = (mock.resultcount = value)
MOI.set!(mock::MockOptimizer, ::MOI.TerminationStatus, value::MOI.TerminationStatusCode) = (mock.terminationstatus = value)
MOI.set!(mock::MockOptimizer, ::MOI.ObjectiveValue, value::Real) = (mock.objectivevalue = value)
MOI.set!(mock::MockOptimizer, ::MOI.PrimalStatus, value::MOI.ResultStatusCode) = (mock.primalstatus = value)
MOI.set!(mock::MockOptimizer, ::MOI.DualStatus, value::MOI.ResultStatusCode) = (mock.dualstatus = value)
MOI.set!(mock::MockOptimizer, ::MockModelAttribute, value::Integer) = (mock.attribute = value)
MOI.supports(mock::MockOptimizer, attr::MOI.AbstractModelAttribute) = MOI.supports(mock.inner_model, attr)
MOI.set!(mock::MockOptimizer, attr::MOI.AbstractModelAttribute, value) = MOI.set!(mock.inner_model, attr, value)
MOI.set!(mock::MockOptimizer, attr::MOI.ObjectiveFunction, value) = MOI.set!(mock.inner_model, attr, xor_variables(value))

MOI.set!(mock::MockOptimizer, attr::MOI.AbstractVariableAttribute, idx::MOI.VariableIndex, value) = MOI.set!(mock.inner_model, attr, xor_index(idx), value)
MOI.set!(mock::MockOptimizer, ::MOI.VariablePrimal, idx::MOI.VariableIndex, value) = (mock.varprimal[xor_index(idx)] = value)
MOI.set!(mock::MockOptimizer, ::MockVariableAttribute, idx::MOI.VariableIndex, value) = (mock.varattribute[xor_index(idx)] = value)
MOI.set!(mock::MockOptimizer, attr::MOI.AbstractConstraintAttribute, idx::MOI.ConstraintIndex, value) = MOI.set!(mock.inner_model, attr, xor_index(idx), value)
MOI.set!(mock::MockOptimizer, ::MockConstraintAttribute, idx::MOI.ConstraintIndex, value) = (mock.conattribute[xor_index(idx)] = value)
MOI.set!(mock::MockOptimizer, ::MOI.ConstraintDual, idx::MOI.ConstraintIndex, value) = (mock.condual[xor_index(idx)] = value)

MOI.canget(mock::MockOptimizer, ::MOI.ResultCount) = mock.solved
MOI.canget(mock::MockOptimizer, ::MOI.TerminationStatus) = mock.solved
MOI.canget(mock::MockOptimizer, ::MOI.ObjectiveValue) = mock.solved # TODO: may want to simulate false
MOI.canget(mock::MockOptimizer, ::MOI.PrimalStatus) = mock.hasprimal && (mock.resultcount > 0)
MOI.canget(mock::MockOptimizer, ::MOI.DualStatus) = mock.hasdual && (mock.resultcount > 0)
MOI.canget(mock::MockOptimizer, ::MockModelAttribute) = true

MOI.canget(mock::MockOptimizer, attr::MOI.AbstractModelAttribute) = MOI.canget(mock.inner_model, attr)
MOI.get(mock::MockOptimizer, attr::MOI.AbstractModelAttribute) = MOI.get(mock.inner_model, attr)
MOI.get(mock::MockOptimizer, attr::Union{MOI.ListOfVariableIndices,
                                         MOI.ListOfConstraintIndices}) = xor_index.(MOI.get(mock.inner_model, attr))
MOI.get(mock::MockOptimizer, attr::MOI.ObjectiveFunction) = xor_variables(MOI.get(mock.inner_model, attr))

MOI.canget(mock::MockOptimizer, attr::Union{MOI.ConstraintFunction,
                                            MOI.ConstraintSet}, idx::Type{<:MOI.ConstraintIndex}) = MOI.canget(mock.inner_model, attr, idx)

MOI.get(mock::MockOptimizer, attr::Union{MOI.ConstraintSet}, idx::MOI.ConstraintIndex) = MOI.get(mock.inner_model, attr, xor_index(idx))
MOI.get(mock::MockOptimizer, attr::Union{MOI.ConstraintFunction}, idx::MOI.ConstraintIndex) = xor_variables(MOI.get(mock.inner_model, attr, xor_index(idx)))

MOI.canget(mock::MockOptimizer, attr::MOI.AbstractVariableAttribute, IdxT::Type{MOI.VariableIndex}) = MOI.canget(mock.inner_model, attr, IdxT)
MOI.canget(mock::MockOptimizer, attr::MOI.AbstractConstraintAttribute, IdxT::Type{<:MOI.ConstraintIndex}) = MOI.canget(mock.inner_model, attr, IdxT)

# We assume that a full result is loaded if resultcount > 0
MOI.canget(mock::MockOptimizer, ::MOI.VariablePrimal, ::Type{MOI.VariableIndex}) = mock.hasprimal && (mock.resultcount > 0)
MOI.canget(mock::MockOptimizer, ::MOI.ConstraintPrimal, IdxT::Type{<:MOI.ConstraintIndex}) = MOI.canget(mock, MOI.ConstraintFunction(), IdxT) && MOI.canget(mock, MOI.VariablePrimal(), MOI.VariableIndex)
MOI.canget(mock::MockOptimizer, ::MOI.ConstraintDual, ::Type{<:MOI.ConstraintIndex}) = mock.hasdual && (mock.resultcount > 0) && mock.dualstatus != MOI.UnknownResultStatus

MOI.canget(mock::MockOptimizer, ::MockVariableAttribute, ::Type{MOI.VariableIndex}) = length(mock.varattribute) > 0
MOI.canget(mock::MockOptimizer, ::MockConstraintAttribute, ::Type{<:MOI.ConstraintIndex}) = length(mock.conattribute) > 0

# Name
MOI.canget(b::MockOptimizer, IdxT::Type{<:MOI.Index}, name::String) = MOI.canget(b.inner_model, IdxT, name)
MOI.get(b::MockOptimizer, IdxT::Type{<:MOI.Index}, name::String) = xor_index(MOI.get(b.inner_model, IdxT, name))

MOI.get(mock::MockOptimizer, ::MOI.ResultCount) = mock.resultcount
MOI.get(mock::MockOptimizer, ::MOI.TerminationStatus) = mock.terminationstatus
function MOI.get(mock::MockOptimizer, attr::MOI.ObjectiveValue)
    if mock.eval_objective_value
        return get_fallback(mock, attr)
    else
        return mock.objectivevalue
    end
end
MOI.get(mock::MockOptimizer, ::MOI.PrimalStatus) = mock.primalstatus
MOI.get(mock::MockOptimizer, ::MOI.DualStatus) = mock.dualstatus
MOI.get(mock::MockOptimizer, ::MockModelAttribute) = mock.attribute

MOI.get(mock::MockOptimizer, attr::MOI.AbstractVariableAttribute, idx::MOI.VariableIndex) = MOI.get(mock.inner_model, attr, xor_index(idx))
MOI.get(mock::MockOptimizer, ::MockVariableAttribute, idx::MOI.VariableIndex) = mock.varattribute[xor_index(idx)]
MOI.get(mock::MockOptimizer, ::MOI.VariablePrimal, idx::MOI.VariableIndex) = mock.varprimal[xor_index(idx)]
function MOI.get(mock::MockOptimizer, attr::MOI.ConstraintPrimal,
                 idx::MOI.ConstraintIndex)
    return get_fallback(mock, attr, idx)
end
MOI.get(mock::MockOptimizer, attr::MOI.AbstractConstraintAttribute, idx::MOI.ConstraintIndex) = MOI.get(mock.inner_model, attr, xor_index(idx))
function MOI.get(mock::MockOptimizer, attr::MOI.ConstraintDual,
                 idx::MOI.ConstraintIndex{F}) where F
    if mock.eval_variable_constraint_dual &&
        (F == MOI.SingleVariable || F == MOI.VectorOfVariables)
        return get_fallback(mock, attr, idx)
    else
        return mock.condual[xor_index(idx)]
    end
end
MOI.get(mock::MockOptimizer, ::MockConstraintAttribute, idx::MOI.ConstraintIndex) = mock.conattribute[xor_index(idx)]

MOI.supports(mock::MockOptimizer, ::MOI.ObjectiveBound) = true
MOI.canget(mock::MockOptimizer, ::MOI.ObjectiveBound) = !isnan(mock.objectivebound)
MOI.get(mock::MockOptimizer, ::MOI.ObjectiveBound) = mock.objectivebound
function MOI.set!(mock::MockOptimizer, ::MOI.ObjectiveBound, value::Float64)
    mock.objectivebound = value
end

function MOI.empty!(mock::MockOptimizer)
    MOI.empty!(mock.inner_model)
    mock.attribute = 0
    mock.varattribute = Dict{MOI.VariableIndex,Int}()
    mock.conattribute = Dict{MOI.ConstraintIndex,Int}()
    mock.solved = false
    mock.hasprimal = false
    mock.hasdual = false
    mock.terminationstatus = MOI.Success
    mock.resultcount = 0
    mock.objectivevalue = NaN
    mock.objectivebound = NaN
    mock.primalstatus = MOI.UnknownResultStatus
    mock.dualstatus = MOI.UnknownResultStatus
    mock.varprimal = Dict{MOI.VariableIndex,Float64}()
    mock.condual = Dict{MOI.ConstraintIndex,Any}()
    return
end

function MOI.isempty(mock::MockOptimizer)
    # Assumes that variable and constraint attributes can't be set if
    # mock.inner_model is empty.
    # TODO: Default values are currently copied in three places, not good.
    return MOI.isempty(mock.inner_model) && mock.attribute == 0 &&
        !mock.solved && !mock.hasprimal && !mock.hasdual &&
        mock.terminationstatus == MOI.Success &&
        mock.resultcount == 0 && isnan(mock.objectivevalue) &&
        isnan(mock.objectivebound) &&
        mock.primalstatus == MOI.UnknownResultStatus &&
        mock.dualstatus == MOI.UnknownResultStatus
end

MOI.isvalid(mock::MockOptimizer, idx::MOI.Index) = MOI.isvalid(mock.inner_model, xor_index(idx))

function MOI.delete!(mock::MockOptimizer, index::MOI.VariableIndex)
    if !MOI.isvalid(mock, index)
        # The index thrown by `mock.inner_model` would be xored
        throw(MOI.InvalidIndex(index))
    end
    MOI.delete!(mock.inner_model, xor_index(index))
    MOI.delete!(mock.varprimal, index)
end
function MOI.delete!(mock::MockOptimizer, index::MOI.ConstraintIndex)
    if !MOI.isvalid(mock, index)
        # The index thrown by `mock.inner_model` would be xored
        throw(MOI.InvalidIndex(index))
    end
    MOI.delete!(mock.inner_model, xor_index(index))
    MOI.delete!(mock.condual, index)
end

function MOI.modify!(mock::MockOptimizer, c::CI, change::MOI.AbstractFunctionModification)
    MOI.modify!(mock.inner_model, xor_index(c), xor_variables(change))
end

function MOI.set!(mock::MockOptimizer, ::MOI.ConstraintSet, c::CI{F,S}, set::S) where {F<:MOI.AbstractFunction, S<:MOI.AbstractSet}
    MOI.set!(mock.inner_model, MOI.ConstraintSet(), xor_index(c), set)
end

function MOI.set!(mock::MockOptimizer, ::MOI.ConstraintFunction, c::CI{F,S}, func::F) where {F<:MOI.AbstractFunction, S<:MOI.AbstractSet}
    MOI.set!(mock.inner_model, MOI.ConstraintFunction(), xor_index(c), xor_variables(func))
end

function MOI.modify!(mock::MockOptimizer, obj::MOI.ObjectiveFunction, change::MOI.AbstractFunctionModification)
    MOI.modify!(mock.inner_model, obj, xor_variables(change))
end

# TODO: transform

MOI.supportsconstraint(mock::MockOptimizer, F::Type{<:MOI.AbstractFunction}, S::Type{<:MOI.AbstractSet}) = MOI.supportsconstraint(mock.inner_model, F, S)
function MOI.copy!(mock::MockOptimizer, src::MOI.ModelLike; copynames=true)
    if needsallocateload(mock)
        allocateload!(mock, src, copynames)
    else
        defaultcopy!(mock, src, copynames)
    end
end

# Allocate-Load Interface
needsallocateload(mock::MockOptimizer) = mock.needsallocateload || needsallocateload(mock.inner_model)

allocatevariables!(mock::MockOptimizer, nvars) = allocatevariables!(mock.inner_model, nvars)
allocate!(mock::MockOptimizer, attr::MOI.AnyAttribute, value) = allocate!(mock.inner_model, attr, value)
allocate!(mock::MockOptimizer, attr::MOI.ObjectiveFunction, value) = allocate!(mock.inner_model, attr, xor_variables(value))
allocate!(mock::MockOptimizer, attr::MOI.AnyAttribute, idx::MOI.Index, value) = allocate!(mock.inner_model, attr, xor_index(idx), value)
canallocate(mock::MockOptimizer, attr::MOI.AnyAttribute) = canallocate(mock.inner_model, attr)
canallocate(mock::MockOptimizer, attr::MOI.AnyAttribute, IdxT::Type{<:MOI.Index}) = canallocate(mock.inner_model, attr, IdxT)
allocateconstraint!(mock::MockOptimizer, f::MOI.AbstractFunction, s::MOI.AbstractSet) = xor_index(allocateconstraint!(mock.inner_model, xor_variables(f), s))

loadvariables!(mock::MockOptimizer, nvars) = loadvariables!(mock.inner_model, nvars)
load!(mock::MockOptimizer, attr::MOI.AnyAttribute, value) = load!(mock.inner_model, attr, value)
load!(mock::MockOptimizer, attr::MOI.ObjectiveFunction, value) = load!(mock.inner_model, attr, xor_variables(value))
load!(mock::MockOptimizer, attr::MOI.AnyAttribute, idx::MOI.Index, value) = load!(mock.inner_model, attr, xor_index(idx), value)
canload(mock::MockOptimizer, attr::MOI.AnyAttribute) = canload(mock.inner_model, attr)
canload(mock::MockOptimizer, attr::MOI.AnyAttribute, IdxT::Type{<:MOI.Index}) = canload(mock.inner_model, attr, IdxT)
loadconstraint!(mock::MockOptimizer, ci::CI, f::MOI.AbstractFunction, s::MOI.AbstractSet) = loadconstraint!(mock.inner_model, xor_index(ci), xor_variables(f), s)

"""
    set_mock_optimize!(mock::MockOptimizer, opt::Function...)

Sets multiple optimize! function. The first is to be used the first time `MOI.optimize!(mock)` is called, the second function is to be used the second time, ...
"""
function set_mock_optimize!(mock::MockOptimizer, opts::Function...)
    mock.optimize! = rec_mock_optimize(mock, opts...)
end
function rec_mock_optimize(mock::MockOptimizer, opt::Function, opts::Function...)
    (mock::MockOptimizer) -> (opt(mock); mock.optimize! = rec_mock_optimize(mock, opts...))
end
rec_mock_optimize(mock::MockOptimizer, opt::Function) = opt

"""
    mock_optimize!(mock::MockOptimizer, termstatus::MOI.TerminationStatusCode, (primstatus::MOI.ResultStatusCode, varprim::Vector), dualstatus::MOI.ResultStatusCode, conduals::Pair...)

Sets the termination status of `mock` to `termstatus` and the primal (resp. dual) status to `primstatus` (resp. `dualstatus`).
The primal values of the variables in the order returned by `ListOfVariableIndices` are set to `varprim`.
If `termstatus` is missing, it is assumed to be `MOI.Success`.
If `primstatus` is missing, it is assumed to be `MOI.FeasiblePoint`.
If `dualstatus` is missing, it is assumed to be `MOI.FeasiblePoint` if there is a primal solution and `primstatus` is not `MOI.InfeasiblePoint`, otherwise it is `MOI.InfeasibilityCertificate`.
The dual values are set to the values specified by `conduals`. Each pair is of the form `(F,S)=>[...]` where `[...]` is the the vector of dual values for the constraints `F`-in-`S` in the order returned by `ListOfConstraintIndices{F,S}`.
"""
function mock_optimize!(mock::MockOptimizer, termstatus::MOI.TerminationStatusCode, primal, dual...)
    MOI.set!(mock, MOI.TerminationStatus(), termstatus)
    MOI.set!(mock, MOI.ResultCount(), 1)
    mock_primal!(mock, primal)
    mock_dual!(mock, dual...)
end
# Default termination status
mock_optimize!(mock::MockOptimizer, primdual...) = mock_optimize!(mock, MOI.Success, primdual...)
function mock_optimize!(mock::MockOptimizer, termstatus::MOI.TerminationStatusCode)
    MOI.set!(mock, MOI.TerminationStatus(), termstatus)
    MOI.set!(mock, MOI.ResultCount(), 0)
end

# Primal
mock_primal!(mock, primal::Tuple) = mock_primal!(mock, primal...)
function mock_primal!(mock::MockOptimizer, primstatus::MOI.ResultStatusCode, varprim::Vector...)
    MOI.set!(mock, MOI.PrimalStatus(), primstatus)
    mock_varprimal!(mock, varprim...)
end
# Default primal status
mock_primal!(mock::MockOptimizer, varprim::Vector) = mock_primal!(mock, MOI.FeasiblePoint, varprim)
function mock_primal!(mock::MockOptimizer)
    # No primal solution
    mock.hasprimal = false
end

# Sets variable primal to varprim
function mock_varprimal!(mock::MockOptimizer) end
function mock_varprimal!(mock::MockOptimizer, varprim::Vector)
    MOI.set!(mock, MOI.VariablePrimal(), MOI.get(mock, MOI.ListOfVariableIndices()), varprim)
end

# Dual
function mock_dual!(mock::MockOptimizer, dualstatus::MOI.ResultStatusCode, conduals::Pair...)
    MOI.set!(mock, MOI.DualStatus(), dualstatus)
    mock_condual!(mock, conduals...)
end
# Default dual status
function mock_dual!(mock::MockOptimizer, conduals::Pair...)
    status = !mock.hasprimal || MOI.get(mock, MOI.PrimalStatus()) == MOI.InfeasiblePoint ? MOI.InfeasibilityCertificate : MOI.FeasiblePoint
    mock_dual!(mock, status, conduals...)
end
function mock_dual!(mock::MockOptimizer)
    # No dual solution
    mock.hasdual = false
end

# Sets constraint dual to conduals
function mock_condual!(mock::MockOptimizer) end
function mock_condual!(mock::MockOptimizer, condual::Pair, conduals...)
    F, S = condual.first
    duals = condual.second
    for (i, ci) in enumerate(MOI.get(mock, MOI.ListOfConstraintIndices{F, S}()))
        MOI.set!(mock, MOI.ConstraintDual(), ci, duals[i])
    end
    mock_condual!(mock, conduals...)
end
