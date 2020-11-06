### A Pluto.jl notebook ###
# v0.12.6

using Markdown
using InteractiveUtils

# ╔═╡ 24e89936-2048-11eb-2e22-3771c6cbf492
begin
	using LinearAlgebra, NLPModels, Stopping, Test
end

# ╔═╡ 6919e7e4-2047-11eb-1994-67f541031e50
md"
# Stopping

[![Build Status](https://travis-ci.org/vepiteski/Stopping.jl.svg?branch=master)](https://travis-ci.org/vepiteski/Stopping.jl)
[![Coverage Status](https://coveralls.io/repos/vepiteski/Stopping.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/vepiteski/Stopping.jl?branch=julia-0.7)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://vepiteski.github.io/Stopping.jl/dev/)
"

# ╔═╡ bdc19b18-2047-11eb-04a0-f75a546514ce
md"
## How to install
Install and test the Stopping package with the Julia package manager:
```julia
pkg> add Stopping
pkg> test Stopping
```
You can access the most up-to-date version of the Stopping package using:
```julia
pkg> add https://github.com/vepiteski/Stopping.jl
pkg> test Stopping
pkg> status Stopping
```
"

# ╔═╡ 7d8b468e-2047-11eb-118e-9f3f78f0cb2d
md"
## Purpose

Tools to ease the uniformization of stopping criteria in iterative solvers.

When a solver is called on an optimization model, four outcomes may happen:

1. the approximate solution is obtained, the problem is considered solved
2. the problem is declared unsolvable (unboundedness, infeasibility ...)
3. the maximum available resources are not sufficient to compute the solution
4. some algorithm dependent failure happens

This tool eases the first three items above. It defines a type

    mutable struct GenericStopping <: AbstractStopping
        problem       :: Any                  # an arbitrary instance of a problem
        meta          :: AbstractStoppingMeta # contains the used parameters and stopping status
        current_state :: AbstractState        # Current information on the problem
        main_stp :: Union{AbstractStopping, Nothing} # Stopping of the main problem, or nothing
        listofstates :: Union{ListStates, Nothing}   # History of states
        user_specific_struct :: Any                  # User-specific structure

The [StoppingMeta](https://github.com/vepiteski/Stopping.jl/blob/master/src/Stopping/StoppingMetamod.jl) provides default tolerances, maximum resources, ...  as well as (boolean) information on the result.

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
"

# ╔═╡ 8f532b5c-2047-11eb-3ece-b5c66e3c1030
md"
## Example

As an example, a naive version of the Newton method is provided [here](https://github.com/vepiteski/Stopping.jl/blob/master/test/examples/newton.jl). First we import the packages:
"

# ╔═╡ 2b84477c-2048-11eb-00cf-4d8cbd285252
md"
We consider a quadratic test function, and create an uncontrained quadratic optimization problem using [NLPModels](https://github.com/JuliaSmoothOptimizers/NLPModels.jl):
"

# ╔═╡ 31305268-2048-11eb-0145-9dded700c8c7
begin
	A = rand(5, 5); Q = A' * A;
	f(x) = 0.5 * x' * Q * x + sum(x)
	nlp = ADNLPModel(f,  ones(5))
	
	nlp.meta.nvar
end

# ╔═╡ 3afd8c90-2048-11eb-1195-b7a16248f31d
md"
We now initialize the *NLPStopping*. First create a State. We use [unconstrained_check](https://github.com/vepiteski/Stopping.jl/blob/master/src/Stopping/nlp_admissible_functions.jl) as an optimality function
"

# ╔═╡ 41b7df4a-2048-11eb-0823-3f28002e28a8
begin
	nlp_at_x = NLPAtX(ones(5))
	#stop_nlp = NLPStopping(nlp, nlp_at_x, optimality_check = unconstrained_check)
	#Note that, since we used a default State, an alternative would have been:
	stop_nlp = NLPStopping(nlp)
	
	stop_nlp.meta.atol
end

# ╔═╡ 63dc7522-2048-11eb-2d72-5353bdba39eb
md"
Now a basic version of Newton to illustrate how to use Stopping.
"

# ╔═╡ 675e49aa-2048-11eb-2263-65258ce6508e
begin
	function newton(stp :: NLPStopping)

		#Notations
		pb = stp.pb; state = stp.current_state;
		#Initialization
		xt = state.x

		#First, call start! to check optimality and set an initial configuration
		#(start the time counter, set relative error ...)
		OK = update_and_start!(stp, x = xt, gx = grad(pb, xt), Hx = hess(pb, xt))

		while !OK
			#Compute the Newton direction (state.Hx only has the lower triangular)
			d = (state.Hx + state.Hx' - diagm(0 => diag(state.Hx))) \ (- state.gx)
			#Update the iterate
			xt = xt + d
			#Update the State and call the Stopping with stop!
			OK = update_and_stop!(stp, x = xt, gx = grad(pb, xt), Hx = hess(pb, xt))
		end

		return stp
	end
end

# ╔═╡ 78f87730-2048-11eb-14e4-0b692bf6e7a8
md"
Finally, we can call the algorithm with our Stopping, and consult the Stopping to know what happened.
"

# ╔═╡ 7be7cb08-2048-11eb-31ea-132cefd60433
begin
	newton(stop_nlp)	
	
	#We can then ask stop_nlp the final status
	status(stop_nlp, list = true)
end

# ╔═╡ 8de7e950-2048-11eb-3e1b-b3d350e346c8
begin
	#Explore the final values in stop_nlp.current_state
	@show "Final solution is $(stop_nlp.current_state.x)"
end

# ╔═╡ 9de11048-2048-11eb-3ffc-7fc8110510e4
md"
We reached optimality, and thanks to the Stopping structure this simple looking
algorithm verified at each step of the algorithm:
- time limit has been respected;
- evaluations of the problem are not excessive;
- the problem is not unbounded (w.r.t. x and f(x));
- there is no NaN in x, f(x), g(x), H(x);
- the maximum number of iteration (call to stop!) is limited.
"

# ╔═╡ ceaf484e-2047-11eb-018c-4b5f3696e597
md"
### Your Stopping your way

The GenericStopping (with GenericState) provides a complete structure to handle stopping criteria.
Then, depending on the problem structure, you can specialize a new Stopping by
redefining a State and some functions specific to your problem.

We provide some specialization of the GenericStopping for optimization:
  * [NLPStopping](https://github.com/vepiteski/Stopping.jl/blob/master/src/Stopping/NLPStoppingmod.jl) with [NLPAtX](https://github.com/vepiteski/Stopping.jl/blob/master/src/State/NLPAtXmod.jl) as a specialized State: for non-linear programming (based on [NLPModels](https://github.com/JuliaSmoothOptimizers/NLPModels.jl));
  * [LAStopping](https://github.com/vepiteski/Stopping.jl/blob/master/src/Stopping/LinearAlgebraStopping.jl) with [GenericState](https://github.com/vepiteski/Stopping.jl/blob/master/src/State/GenericStatemod.jl): for linear algebra problems.
  * [LS_Stopping](https://github.com/vepiteski/Stopping.jl/blob/master/src/Stopping/LineSearchStoppingmod.jl) with [LSAtT](https://github.com/vepiteski/Stopping.jl/blob/master/src/State/LSAtTmod.jl) as a specialized State: for 1d optimization;
  * more to come...

### How To Stopping

Consult the [HowTo tutorial](https://github.com/vepiteski/Stopping.jl/blob/master/test/examples/runhowto.jl) to learn more about the possibilities offered by Stopping.

You can also access other examples of algorithms in the [test/examples](https://github.com/vepiteski/Stopping.jl/blob/master/test/examples/) folder, which for instance illustrate the strenght of Stopping with subproblems:
* Consult the [OptimSolver tutorial](https://github.com/vepiteski/Stopping.jl/blob/master/test/examples/run-optimsolver.jl) for more on how to use Stopping with nested algorithms.
* Check the [Benchmark tutorial](https://github.com/vepiteski/Stopping.jl/blob/master/test/examples/benchmark.jl) to see how Stopping can combined with [SolverBenchmark.jl](https://juliasmoothoptimizers.github.io/SolverBenchmark.jl/).
* Stopping can be adapted to closed solvers via a buffer function as in [Buffer tutorial](https://github.com/vepiteski/Stopping.jl/blob/master/test/examples/buffer.jl) for an instance with [Ipopt](https://github.com/JuliaOpt/Ipopt.jl) via [NLPModelsIpopt](https://github.com/JuliaSmoothOptimizers/NLPModelsIpopt.jl).

## Long-Term Goals

Stopping is aimed as a tool for improving the reusability and robustness in the implementation of iterative algorithms. We warmly welcome any feedback or comment leading to potential improvements.

Future work will address more sophisticated problems such as mixed-integer optimization problems, optimization with uncertainty. The list of suggested optimality functions will be enriched with state of the art conditions.
"

# ╔═╡ Cell order:
# ╟─6919e7e4-2047-11eb-1994-67f541031e50
# ╟─bdc19b18-2047-11eb-04a0-f75a546514ce
# ╟─7d8b468e-2047-11eb-118e-9f3f78f0cb2d
# ╟─8f532b5c-2047-11eb-3ece-b5c66e3c1030
# ╠═24e89936-2048-11eb-2e22-3771c6cbf492
# ╠═2b84477c-2048-11eb-00cf-4d8cbd285252
# ╠═31305268-2048-11eb-0145-9dded700c8c7
# ╟─3afd8c90-2048-11eb-1195-b7a16248f31d
# ╠═41b7df4a-2048-11eb-0823-3f28002e28a8
# ╟─63dc7522-2048-11eb-2d72-5353bdba39eb
# ╠═675e49aa-2048-11eb-2263-65258ce6508e
# ╟─78f87730-2048-11eb-14e4-0b692bf6e7a8
# ╠═7be7cb08-2048-11eb-31ea-132cefd60433
# ╠═8de7e950-2048-11eb-3e1b-b3d350e346c8
# ╟─9de11048-2048-11eb-3ffc-7fc8110510e4
# ╟─ceaf484e-2047-11eb-018c-4b5f3696e597
