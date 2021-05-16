var documenterSearchIndex = {"docs":
[{"location":"reference/simulation/#Simulation","page":"Simulation","title":"Simulation","text":"","category":"section"},{"location":"reference/simulation/","page":"Simulation","title":"Simulation","text":"instance\nsimulate\nevaluate\ncalibrate","category":"page"},{"location":"reference/simulation/#Cropbox.instance","page":"Simulation","title":"Cropbox.instance","text":"instance(S; <keyword arguments>) -> S\n\nMake an instance of system S with an initial condition specified in configuration and additional options.\n\nSee also: @config, simulate\n\nArguments\n\nS::Type{<:System}: type of system to be instantiated.\n\nKeyword Arguments\n\nconfig=(): configuration containing parameter values for the system.\noptions=(): keyword arguments passed down to the constructor of S; named tuple expected.\nseed=nothing: random seed initialized before parsing configuration and making an instance.\n\nExamples\n\njulia> @system S(Controller) begin\n           a => 1 ~ preserve(parameter)\n           b(a) ~ accumulate\n       end;\n\njulia> instance(S)\nS\n  context = <Context>\n  config = <Config>\n  a = 1.0\n  b = 0.0\n\n\n\n\n\n","category":"function"},{"location":"reference/simulation/#Cropbox.simulate","page":"Simulation","title":"Cropbox.simulate","text":"simulate([f,] S[, layout, [configs]]; <keyword arguments>) -> DataFrame\n\nRun simulations by making instance of system S with given configuration to generate an output in the form of DataFrame. layout contains a list of variables to be saved in the output. A layout of single simulation can be specified in the layout arguments placed as keyword arguments. configs contains a list of configurations for each run of simulation. Total number of simulation runs equals to the size of configs. For a single configuration, config keyword argument may be preferred. Optional callback function f allows do-block syntax to specify snatch argument for finer control of output format.\n\nSee also: instance, @config\n\nArguments\n\nS::Type{<:System}: type of system to be simulated.\nlayout::Vector: list of output layout definition in a named tuple (; base, index, target, meta).\nconfigs::Vector: list of configurations for defining multiple runs of simluations.\n\nKeyword Arguments\n\nLayout\n\nbase=nothing: base system where index and target are populated; default falls back to the instance of S.\nindex=nothing: variables to construct index columns of the output; default falls back to context.clock.time.\ntarget=nothing: variables to construct non-index columns of the output; default includes most variables in the root instance.\nmeta=nothing: name of systems in the configuration to be included in the output as metadata.\n\nConfiguration\n\nconfig=(): a single configuration for the system (can't be used with configs).\nconfigs=[]: multiple configurations for the system (can't be used with config nor configs argument).\nseed=nothing: random seed for resetting each simulation run.\n\nProgress\n\nstop=nothing: condition checked before calling updates for the instance; default stops with no update.\nsnap=nothing: condition checked to decide if a snapshot of current update is saved in the output; default snaps all updates.\nsnatch=nothing: callback for modifying intermediate output; list of DataFrame D collected from current update and the instance of system s are provided.\nverbose=true: shows a progress bar.\n\nFormat\n\nnounit=false: remove units from the output.\nlong=false: convert output table from wide to long format.\n\nExamples\n\njulia> @system S(Controller) begin\n           a => 1 ~ preserve(parameter)\n           b(a) ~ accumulate\n       end;\n\njulia> simulate(S; stop=1)\n2×3 DataFrame\n Row │ time       a        b\n     │ Quantity…  Float64  Float64\n─────┼─────────────────────────────\n   1 │    0.0 hr      1.0      0.0\n   2 │    1.0 hr      1.0      1.0\n\n\n\n\n\n","category":"function"},{"location":"reference/simulation/#Cropbox.evaluate","page":"Simulation","title":"Cropbox.evaluate","text":"evaluate(S, obs; <keyword arguments>) -> Number | Tuple\n\nCompare output of simulation results for the given system S and observation data obs with a choice of evaluation metric.\n\nArguments\n\nS::Type{<:System}: type of system to be evaluated.\nobs::DataFrame: observatioan data to be used for evaluation.\n\nKeyword Arguments\n\nConfiguration\n\nconfig=(): a single configuration for the system (can't be used with configs).\nconfigs=[]: multiple configurations for the system (can't be used with config).\n\nLayout\n\nindex=nothing: variables to construct index columns of the output; default falls back to context.clock.time.\ntarget: variables to construct non-index columns of the output.\n\nEvaluation\n\nmetric=nothing: evaluation metric (:rmse, :nrmse, :mae, :mape, :ef, :dr); default is RMSE.\n\nRemaining keyword arguments are passed down to simulate with regard to running system S.\n\nSee also: simulate, calibrate, @config\n\nExamples\n\njulia> @system S(Controller) begin\n           a => 19 ~ preserve(u\"m/hr\", parameter)\n           b(a) ~ accumulate(u\"m\")\n       end;\n\njulia> obs = DataFrame(time=10u\"hr\", b=200u\"m\");\n\njulia> configs = @config !(:S => :a => [19, 21]);\n\njulia> evaluate(S, obs; configs, target=:b, stop=10u\"hr\")\n10.0 m\n\n\n\n\n\n","category":"function"},{"location":"reference/simulation/#Cropbox.calibrate","page":"Simulation","title":"Cropbox.calibrate","text":"calibrate(S, obs; <keyword arguments>) -> Config | OrderedDict\n\nObtain a set of parameters for the given system S that simulates provided observation obs closely as possible. A multitude of simulations are conducted with a differing combination of parameter sets specified by the range of possible values and the optimum is selected based on a choice of evaluation metric. Internally, differential evolution algorithm from BlackboxOptim.jl is used.\n\nArguments\n\nS::Type{<:System}: type of system to be calibrated.\nobs::DataFrame: observatioan data to be used for calibration.\n\nKeyword Arguments\n\nConfiguration\n\nconfig=(): a single base configuration for the system (can't be used with configs).\nconfigs=[]: multiple base configurations for the system (can't be used with config).\n\nLayout\n\nindex=nothing: variables to construct index columns of the output; default falls back to context.clock.time.\ntarget: variables to construct non-index columns of the output.\n\nCalibration\n\nparameters: parameters with a range of boundary values to be calibrated within.\nmetric=nothing: evaluation metric (:rmse, :nrmse, :mae, :mape, :ef, :dr); default is RMSE.\n\nMulti-objective\n\nweight=nothing: weights for calibrating multiple targets; default assumes equal weights.\npareto=false: returns a dictionary containing Pareto frontier instead of a single solution satisfying multiple targets.\n\nAdvanced\n\noptim=(): extra options for BlackBoxOptim.bboptimize.\n\nRemaining keyword arguments are passed down to simulate with regard to running system S.\n\nSee also: simulate, evaluate, @config\n\nExamples\n\njulia> @system S(Controller) begin\n           a => 0 ~ preserve(parameter)\n           b(a) ~ accumulate\n       end;\n\njulia> obs = DataFrame(time=10u\"hr\", b=200);\n\njulia> p = calibrate(S, obs; target=:b, parameters=:S => :a => (0, 100), stop=10)\n...\nConfig for 1 system:\n  S\n    a = 20.0\n\n\n\n\n\n","category":"function"},{"location":"reference/#Index","page":"Index","title":"Index","text":"","category":"section"},{"location":"reference/","page":"Index","title":"Index","text":"","category":"page"},{"location":"reference/declaration/#Declaration","page":"Declaration","title":"Declaration","text":"","category":"section"},{"location":"reference/declaration/","page":"Declaration","title":"Declaration","text":"@system\n@config","category":"page"},{"location":"reference/declaration/#Cropbox.@system","page":"Declaration","title":"Cropbox.@system","text":"@system name[{patches..}][(mixins..)] [<: type] [decl] -> Type{<:System}\n\nDeclare a new system called name with new variables declared in decl block using a custom syntax. The resultant system is subtype of System or a custom type. mixins allows reusing specification of existing systems to be pasted into the declaration of new system. patches may provide type substitution and/or constant definition needed for advanced use.\n\nVariable\n\nname[(args..; kwargs..)][: alias] [=> expr] [~ [state][::type|<:type][(tags..)]]\n\nname: variable name; usually short abbreviation.\nargs: automatically bound depending variables\nkwargs: custom bound depending variables; used by call and integrate.\nalias: alternative name; long description.\nexpr: state-specific code snippet; use begin-end block for multiple statements.\ntype: internal data type; default is Float64 for many, but not all, variables.\ntags: state-specific options; unit, min/max, etc.\n\nStates\n\nhold: marks a placeholder for variable shared between mixins.\nwrap: passes a state variable to other fucnction as is with no unwrapping its value.\nadvance: manages a time-keeping variable; time and tick from Clock.\npreserve: keeps initially assigned value with no further updates; constants, parameters.\ntabulate: makes a two dimensional table with named keys; i.e. partitioning table.\ninterpolate: makes a curve fuction interpolated with discrete values; i.e. soil characteristic curve.\ntrack: evaluates variable expression as is for each update.\nremember: keeps tracking variable until a certain condition is met; essentially track turning into preserve.\nprovide: manages a table of time-series in DataFrame.\ndrive: fetchs the current value from a time-series; maybe supplied by provide.\ncall: defines a partial function bound with some variables.\nintegrate: calculates integral using Gaussian method; not for time domain.\naccumulate: emulates integration of rate variable over time; essentially Euler method.\ncapture: calculates difference between integration for each time step.\nflag: sets a boolean flag; essentially track::Bool.\nproduce: attaches a new instance of system dynamically constructed; i.e. root structure growth.\nbisect: solves nonlinear equation using bisection method; i.e. gas-exchange model coupling.\nsolve: solves polynomical equation symbolically; i.e. quadratic equations in photosynthesis model.\n\nExamples\n\njulia> @system S(Controller) begin\n           a => 1 ~ preserve(parameter)\n           b(a) ~ accumulate\n       end\nS\n\n\n\n\n\n","category":"macro"},{"location":"reference/declaration/#Cropbox.@config","page":"Declaration","title":"Cropbox.@config","text":"@config c.. -> Config | Vector{Config}\n\nConstruct a set or multiple sets of configuration.\n\nA basic unit of configuration for a system S is represented by a pair in the form of S => pv. System name S is expressed in a symbol. If actual type of system is used, its name will be automatically converted to a symbol.\n\nA parameter name and corresponding value is then represented by another pair in the form of p => v. When specifiying multiple parameters, a tuple of pairs like (p1 => v1, p2 => v2) or a named tuple like (p1 = v1, p2 = v2) can be used. Parameter name must be a symbol and should indicate a variable declared with parameter tag as often used by preserve state variable. For example, :S => (:a => 1, :b => 2) has the same meaning as S => (a = 1, b = 2) in the same scope.\n\nConfigurations for multiple systems can be concatenated by a tuple. Multiple elements in c separated by commas implicitly forms a tuple. For example, :S => (:a => 1, :b => 2), :T => :x => 1 represents a set of configuration for two systems S and T with some parameters. When the same names of system or variable appears again during concatenation, it will be overriden by later ones in an order appeared in a tuple. For example, :S => :a => 1, :S => :a => 2 results into :S => :a => 2. Instead of commas, + operator can be used in a similar way as (:S => :a => 1) + (:S => :a => 2). Note parentheses placed due to operator precedence.\n\nWhen multiple sets of configurations are needed, as in configs for simulate, a vector of Config is used. This macro supports some convenient ways to construct a vector by composing simpler configurations. Prefix operator ! allows expansion of any iterable placed in the configuration value. Infix operator * allows multiplication of a vector of configurations with another vector or a single configuration to construct multiple sets of configurations. For example, !(:S => :a => 1:2) is expanded into two sets of separate configurations [:S => :a => 1, :S => :a => 2]. (:S => :a => 1:2) * (:S => :b => 0) is multiplied into [:S => (a = 1, b = 0), :S => (a = 2, b = 0)].\n\nExamples\n\njulia> @config :S => (:a => 1, :b => 2)\nConfig for 1 system:\n  S\n    a = 1\n    b = 2\n\njulia> @config :S => :a => 1, :S => :a => 2\nConfig for 1 system:\n  S\n    a = 2\n\njulia> @config !(:S => :a => 1:2)\n2-element Vector{Config}:\n <Config>\n <Config>\n\njulia> @config (:S => :a => 1:2) * (:S => :b => 0)\n2-element Vector{Config}:\n <Config>\n <Config>\n\n\n\n\n\n","category":"macro"},{"location":"reference/inspection/#Inspection","page":"Inspection","title":"Inspection","text":"","category":"section"},{"location":"reference/inspection/","page":"Inspection","title":"Inspection","text":"look\n@look\ndive","category":"page"},{"location":"reference/inspection/#Cropbox.look","page":"Inspection","title":"Cropbox.look","text":"look(s[, k])\n\nLook up information about system or variable. Both system type S and instance s are accepted. For looking up a variable, the name of variable k needs to be specified in a symbol.\n\nSee also: @look, dive\n\nArguments\n\ns::Union{System,Type{<:System}}: target system.\nk::Symbol: name of variable.\n\nExamples\n\njulia> \"my system\"\n       @system S(Controller) begin\n           \"a param\"\n           a => 1 ~ preserve(parameter)\n       end;\n\njulia> s = instance(S);\n\njulia> look(s)\n[doc]\n  my system\n\n[system]\nS\n  context = <Context>\n  config = <Config>\n  a = 1.0\njulia> look(s, :a)\n[doc]\n  a param\n\n[code]\n  a => 1 ~ preserve(parameter)\n\n[value]\n1.0\n\n\n\n\n\n","category":"function"},{"location":"reference/inspection/#Cropbox.@look","page":"Inspection","title":"Cropbox.@look","text":"@look ex\n@look s[, k]\n\nMacro version of look supports a convenient way of accessing variable without relying on symbol. Both @look s.a and @look s a work the same as look(s, :a).\n\nSee also: look\n\nExamples\n\njulia> \"my system\"\n       @system S(Controller) begin\n           \"a param\"\n           a => 1 ~ preserve(parameter)\n       end;\n\njulia> @look S.a\n[doc]\n  a param\n\n[code]\n  a => 1 ~ preserve(parameter)\n\n\n\n\n\n","category":"macro"},{"location":"reference/inspection/#Cropbox.dive","page":"Inspection","title":"Cropbox.dive","text":"dive(s)\n\nInspect an instance of system s by navigating hierarchy of variables displayed in a tree structure.\n\nPressing up/down arrow keys allows navigation. Press 'enter' to dive into a deeper level and press 'q' to come back. A leaf node of the tree shows an output of look regarding the variable. Pressing 'enter' again would return a variable itself and exit to REPL.\n\nOnly works in a terminal environment; not working on Jupyter Notebook.\n\nSee also: look\n\nArguments\n\ns::System: instance of target system.\n\nExamples\n\njulia> @system S(Controller) begin\n           a => 1 ~ preserve(parameter)\n       end;\n\njulia> s = instance(S);\n\njulia> dive(s)\nS\n → context = <Context>\n   config = <Config>\n   a = 1.0\n\n\n\n\n\n","category":"function"},{"location":"#Cropbox","page":"Home","title":"Cropbox","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Cropbox is a declarative modeling framework specifically designed for developing crop models. The goal is to let crop modelers focus on what the model should look like rather than how the model is technically implemented under the hood.","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Cropbox.jl is available through Julia package manager.","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Pkg\nPkg.add(\"Cropbox\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"There is a Docker image with Cropbox precompiled for convenience. By default, Jupyter Lab will be launched.","category":"page"},{"location":"","page":"Home","title":"Home","text":"$ docker run -it --rm -p 8888:8888 cropbox/cropbox","category":"page"},{"location":"","page":"Home","title":"Home","text":"If REPL is preferred, you can directly launch an instance of Julia session.","category":"page"},{"location":"","page":"Home","title":"Home","text":"$ docker run -it --rm cropbox/cropbox julia\n               _\n   _       _ _(_)_     |  Documentation: https://docs.julialang.org\n  (_)     | (_) (_)    |\n   _ _   _| |_  __ _   |  Type \"?\" for help, \"]?\" for Pkg help.\n  | | | | | | |/ _` |  |\n  | | |_| | | | (_| |  |  Version 1.6.1 (2021-04-23)\n _/ |\\__'_|_|_|\\__'_|  |  Official https://julialang.org/ release\n|__/                   |\n\njulia>","category":"page"},{"location":"","page":"Home","title":"Home","text":"The docker image can be also launched via Binder without installing anything local.","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: Binder)","category":"page"},{"location":"#Getting-Started","page":"Home","title":"Getting Started","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Let's start with Cropbox.","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Cropbox","category":"page"},{"location":"","page":"Home","title":"Home","text":"In Cropbox, system is where the model specification is written down in a slightly repurposed Julia syntax, which is an approach generally called domain specific language (DSL).","category":"page"},{"location":"","page":"Home","title":"Home","text":"@system S(Controller) begin\n    a(a) ~ accumulate(init = 1)\nend\n; # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"In this simple example, our system S has a single variable named a which accumulates itself starting from an initial value of 1. Once the model is defined as a system, users can run simulations.","category":"page"},{"location":"","page":"Home","title":"Home","text":"simulate(S) # hide\nr = simulate(S, stop = 5)\nshow(stdout, \"text/plain\", r) # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"Here is a line plot of the variable a after running simulation updated for five times.","category":"page"},{"location":"","page":"Home","title":"Home","text":"visualize(r, :time, :a; kind = :line)","category":"page"},{"location":"","page":"Home","title":"Home","text":"A more comprehensive guide in the next page will tell more about concepts and features behind Cropbox.","category":"page"},{"location":"reference/visualization/#Visualization","page":"Visualization","title":"Visualization","text":"","category":"section"},{"location":"reference/visualization/","page":"Visualization","title":"Visualization","text":"plot\nplot!\nvisualize\nvisualize!\nmanipulate","category":"page"},{"location":"reference/visualization/#Cropbox.plot","page":"Visualization","title":"Cropbox.plot","text":"plot(df::DataFrame, x, y; <keyword arguments>) -> Plot\nplot(X::Vector, Y::Vector; <keyword arguments>) -> Plot\nplot(df::DataFrame, x, y, z; <keyword arguments>) -> Plot\n\nPlot a graph from provided data source. The type of graph is selected based on arguments.\n\nSee also: plot!, visualize\n\n\n\n\n\n","category":"function"},{"location":"reference/visualization/#Cropbox.plot!","page":"Visualization","title":"Cropbox.plot!","text":"plot!(p, <arguments>; <keyword arguments>) -> Plot\n\nUpdate an existing Plot object p by appending a new graph made with plot.\n\nSee also: plot\n\nArguments\n\np::Union{Plot,Nothing}: plot object to be updated; nothing creates a new plot.\n\n\n\n\n\n","category":"function"},{"location":"reference/visualization/#Cropbox.visualize","page":"Visualization","title":"Cropbox.visualize","text":"visualize(<arguments>; <keyword arguments>) -> Plot\n\nMake a plot from an output collected by running necessary simulations. A convenient function to run both simulate and plot together.\n\nSee also: visualize!, simulate, plot, manipulate\n\nExamples\n\njulia> @system S(Controller) begin\n           a(a) => a ~ accumulate(init=1)\n       end;\n\njulia> visualize(S, :time, :a; stop=5, kind=:line)\n       ┌────────────────────────────────────────┐\n    32 │                                       :│\n       │                                      : │\n       │                                     :  │\n       │                                    :   │\n       │                                   :    │\n       │                                  :     │\n       │                                 :      │\n  a    │                                :       │\n       │                              .'        │\n       │                            .'          │\n       │                          .'            │\n       │                       ..'              │\n       │                   ..''                 │\n       │             ....''                     │\n     1 │.........''''                           │\n       └────────────────────────────────────────┘\n       0                                        5\n                      time (hr)\n\n\n\n\n\n","category":"function"},{"location":"reference/visualization/#Cropbox.visualize!","page":"Visualization","title":"Cropbox.visualize!","text":"visualize!(p, <arguments>; <keyword arguments>) -> Plot\n\nUpdate an existing Plot object p by appending a new graph made with visualize.\n\nSee also: visualize\n\nArguments\n\np::Union{Plot,Nothing}: plot object to be updated; nothing creates a new plot.\n\n\n\n\n\n","category":"function"},{"location":"reference/visualization/#Cropbox.manipulate","page":"Visualization","title":"Cropbox.manipulate","text":"manipulate(f::Function; parameters, config=())\n\nCreate an interactive plot updated by callback f. Only works in Jupyter Notebook.\n\nArguments\n\nf::Function: callback for generating a plot; interactively updated configuration c is provided.\nparameters: parameters adjustable with interactive widgets; value should be an iterable.\nconfig=(): a baseline configuration.\n\n\n\n\n\nmanipulate(args...; parameters, kwargs...)\n\nCreate an interactive plot by calling manipulate with visualize as a callback.\n\nSee also: visualize\n\nArguments\n\nargs: positional arguments for visualize.\nparameters: parameters for manipulate.\nkwargs: keyword arguments for visualize.\n\n\n\n\n\n","category":"function"}]
}
