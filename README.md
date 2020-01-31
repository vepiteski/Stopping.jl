# Stopping

[![Build Status](https://travis-ci.org/Goysa2/Stopping.jl.svg?branch=master)](https://travis-ci.org/Goysa2/Stopping.jl)

[![Coverage Status](https://coveralls.io/repos/Goysa2/Stopping.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/Goysa2/Stopping.jl?branch=julia-0.7)

[![codecov.io](http://codecov.io/github/Goysa2/Stopping.jl/coverage.svg?branch=master)](http://codecov.io/github/Goysa2/Stopping.jl?branch=master)

[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://goysa2.github.io/Stopping.jl/dev/)


## Purpose

Tools to ease the uniformization of stopping criteria in iterative solvers.

When a solver is called on an optimization model, four outcomes may happen:

1. the approximate solution is obtained, the problem is considered solved
2. the problem is declared unsolvable (unboundedness, infeasibility ...)
3. the maximum available resources are not sufficient to compute the solution
4. some algorithm dependent failure happens

This tool eases the first three items above. It defines a type

    mutable struct GenericStopping <: AbstractStopping
        problem       :: Any          # an arbitrary instance of a problem
        meta          :: AbstractStoppingMeta # contains the used parameters
        current_state :: AbstractState        # the current state

The [StoppingMeta](https://github.com/Goysa2/Stopping.jl/blob/master/src/Stopping/StoppingMetamod.jl) provides default tolerances, maximum resources, ...  as well as (boolean) information on the result.

### Your Stopping your way

The GenericStopping (with GenericState) provides a complete structure to handle stopping criteria.
Then, depending on your problem, you can specialize a new Stopping by redefining
a State and some functions specific to your problem.

We provide some specialization of the GenericStopping for optimization :
  * [NLPStopping](https://github.com/Goysa2/Stopping.jl/blob/master/src/Stopping/NLPStoppingmod.jl): for non-linear programming (based on [NLPModels](https://github.com/JuliaSmoothOptimizers/NLPModels.jl)) uses [NLPAtX](https://github.com/Goysa2/Stopping.jl/blob/master/src/State/NLPAtXmod.jl) as a specialized State;
  * [LS_Stopping](https://github.com/Goysa2/Stopping.jl/blob/master/src/Stopping/LineSearchStoppingmod.jl): for 1d optimization uses [LSAtT](https://github.com/Goysa2/Stopping.jl/blob/master/src/State/LSAtTmod.jl) as a specialized State;
  * more to come...

In these examples, the function `optimality_residual` computes the residual of the optimality conditions is an additional attribute of the type.

## Functions

The tool provides two main functions:
* `start!(stp :: AbstractStopping)` initializes the time and the tolerance at the starting point and check wether the initial guess is optimal.
* `stop!(stp :: AbstractStopping)` checks optimality of the current guess as well as failure of the system (unboundedness for instance) and maximum resources (number of evaluations of functions, elapsed time ...)

Stopping uses the informations furnished by the State to evaluate its functions. Communication between the two can be done through the following functions:
* `update_and_start!(stp :: AbstractStopping; kwargs...)` updates the states with informations furnished as kwargs and then call start!.
* `update_and_stop!(stp :: AbstractStopping; kwargs...)` updates the states with informations furnished as kwargs and then call stop!.
* `fill_in!(stp :: AbstractStopping, x :: Iterate)` a function that fill in all the State with all the informations required to correctly evaluate the stopping functions. This can reveal useful, for instance, if the user do not trust the informations furnished by the algorithm in the State.
* `reinit!(stp :: AbstractStopping)` reinitialize the entries of
the Stopping to reuse for another call.

Consult the [HowTo tutorial](https://github.com/Goysa2/Stopping.jl/blob/master/test/examples/runhowto.jl) to learn more about the possibilities offered by Stopping.

You can also access other examples of algorithms in the [test/examples](https://github.com/Goysa2/Stopping.jl/blob/master/test/examples/) folder, which for instance illustrate the strenght of Stopping with subproblems.

## How to install
Install and test the Stopping package with the Julia package manager:
```julia
pkg> add Stopping
pkg> test Stopping
```
You can access the most-up-to date version of the Stopping package using:
```julia
pkg> add https://github.com/Goysa2/Stopping.jl
pkg> test Stopping
```
## Example

As an example, a naïve version of the Newton method is provided [here](https://github.com/Goysa2/Stopping.jl/blob/master/test/examples/newton.jl). First we import the packages:
```
using NLPModels, Stopping
```
We consider a quadratic test function, and create an uncontrained quadratic optimization problem using [NLPModels](https://github.com/JuliaSmoothOptimizers/NLPModels.jl):
```
A = rand(5, 5); Q = A' * A;
f(x) = 0.5 * x' * Q * x
nlp = ADNLPModel(f,  ones(5))
```

We now initialize the NLPStopping. First create a State.
```
nlp_at_x = NLPAtX(ones(5))
```
We use [unconstrained_check](https://github.com/Goysa2/Stopping.jl/blob/master/src/Stopping/nlp_admissible_functions.jl) as an optimality function
```
stop_nlp = NLPStopping(nlp, (x,y) -> unconstrained_check(x,y), nlp_at_x)
```
Note that, since we used a default State, an alternative would have been:
```
stop_nlp = NLPStopping(nlp)
```

Now a basic version of Newton to illustrate how to use Stopping.
```
function newton(stp :: NLPStopping)

    #Notations
    pb = stp.pb; state = stp.current_state;
    #Initialization
    xt = state.x

    #First, call start! to check optimality and set an initial configuration
    #(start the time counter, set relative error ...)
    OK = update_and_start!(stp, x = xt, gx = grad(pb, xt), Hx = hess(pb, xt))

    while !OK
        #Compute the Newton direction
        d = -inv(state.Hx) * state.gx
        #Update the iterate
        xt = xt + d
        #Update the State and call the Stopping with stop!
        OK = update_and_stop!(stp, x = xt, gx = grad(pb, xt), Hx = hess(pb, xt))
    end

    return stp
end
```
Finally, we can call the algorithm with our Stopping:
```
stop_nlp = newton(stop_nlp)
```
and consult the Stopping to know what happened
```
#We can then ask stop_nlp the final status
@test :Optimal in status(stop_nlp, list = true)
#Explore the final values in stop_nlp.current_state
printstyled("Final solution is $(stop_nlp.current_state.x)", color = :green)
```
We reached optimality, and thanks to the Stopping structure this simple looking
algorithm verified at each step of the algorithm:
- time limit has been respected;
- evaluations of the problem are not excessive;
- the problem is not unbounded (w.r.t. x and f(x));
- there is no NaN in x, f(x), g(x), H(x);
- the maximum number of iteration (call to stop!) is limited.

## Long-Term Goals

Stopping is aimed as a tool for improving the reusability and robustness in the implementation of iterative algorithms. We warmly welcome any feedback or comment leading to potential improvements.

Future work will address more sophisticated problems such as mixed-integer optimization problems, optimization with uncertainty. The list of suggester optimality functions will be enriched with state of the art conditions.
