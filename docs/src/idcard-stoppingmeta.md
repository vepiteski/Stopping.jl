## Stopping's attributes ID: StoppingMeta

Usual instances of `AbstractStopping` contains a `StoppingMeta <: AbstractStoppingMeta` (`stp.meta`), which controls the various tolerances and thresholds used by the functions `start!` and `stop!`.
- `atol                :: Number   = 1.0e-6`
- `rtol                :: Number   = 1.0e-15`
- `optimality0         :: Number   = 1.0`
- `tol_check           :: Function = (atol :: Number, rtol :: Number, opt0 :: Number) -> max(atol,rtol*opt0)`
- `tol_check_neg       :: Function = (atol :: Number, rtol :: Number, opt0 :: Number) -> - tol_check(atol,rtol,opt0)`
- `optimality_check    :: Function = (a,b) -> Inf`
- `recomp_tol          :: Bool     = true`
- `unbounded_threshold :: Number   = 1.0e50, #typemax(Float64)`
- `unbounded_x         :: Number   = 1.0e50`
- `max_f               :: Int      = typemax(Int)`
- `max_cntrs           :: Dict{Symbol,Int} = Dict{Symbol,Int64}()`
- `max_eval            :: Int      = 20000`
- `max_iter            :: Int      = 5000`
- `max_time            :: Float64  = 300.0`
- `start_time          :: Float64  = NaN`
- `meta_user_struct    :: Any      = nothing`
- `user_check_func!    :: Function = (stp :: AbstractStopping, start :: Bool) -> nothing`
The default constructor for the meta uses above values, and they can all be modified using keywords
```julia
meta = StoppingMeta(rtol = 0.0) #will set `rtol` as 0.0.
```

`StoppingMeta` also contains the various status related to the checks:
```julia
OK_check(meta) #returns true if one of the check is true.
```

### FAQ: Are there Type constraints when initializing a StoppingMeta?

An `StoppingMeta{TolType, CheckType, MUS, IntType}` is actually a paramtric type:
```julia
checktype(meta) #CheckType: return type of `tol_check` and `tol_check_neg` 
toltype(meta) #TolType: type of the tolerances
metausertype(meta) #MUS: type of the user-defined structure
inttype(meta) #IntType: type of integer tolerances
```

### FAQ: What is `user_check_func!`?

This is a callback function called in the execution of the function `stop!` or `start!`. This function takes two input `stp <: AbstractStopping` and a boolean set as `true` if called from `start!` and `false` if called from `stop!`. To eventually returns a stopping status, the function has to update `stp.meta.stopbyuser`.

For instance, if one want to stop when $$\log(x) < 1$$ in `stop!`:
```julia
function test(stp, start)
  stp.meta.stopbyuser = !start && (log(stp.current_state.x) < 1)
end
user_check_func! = test
```
The exclamation mark (!) is a naming convention used when the function modifies input.
