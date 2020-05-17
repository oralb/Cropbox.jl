module Root

using Cropbox
using Distributions
using MeshCat
import GeometryTypes: Cylinder3, Point3f0
import CoordinateTransformations: IdentityTransformation, LinearMap, RotZX, Transformation, Translation
import Colors: RGBA
import UUIDs

@system Rendering

abstract type ContainerSystem <: System end

@system BaseContainer(Rendering) <: ContainerSystem begin
    dist(; p::Point3f0): distance => -Inf ~ call
end

@system PlantContainer(BaseContainer) <: ContainerSystem begin
    r1: top_radius => 5 ~ preserve(u"cm", parameter)
    r2: bottom_radius => 5 ~ preserve(u"cm", parameter)
    h: height => 100 ~ preserve(u"cm", parameter)
    sq: square => false ~ preserve::Bool(parameter)

    dist(nounit(r1), nounit(r2), nounit(h), sq; p::Point3f0): distance => begin
        x, y, z = p
        if z < -h # below
            -z - h
        elseif 0 < z # above
            z
        else # inside: -h <= z <= 0
            w = -z / h # [0, 1]
            r = (1-w)*r1 + w*r2
            if sq
                max(abs(x), abs(y)) - r
            else
                sqrt(x^2 + y^2) - r
            end
        end
    end ~ call
end

@system Rhizobox(BaseContainer) <: ContainerSystem begin
    l: length => 16u"inch" ~ preserve(u"cm", parameter)
    w: width => 10.5u"inch" ~ preserve(u"cm", parameter)
    h: height => 42u"inch" ~ preserve(u"cm", parameter)

    dist(nounit(l), nounit(w), nounit(h); p::Point3f0): distance => begin
        x, y, z = p
        if z < -h # below
            -z - h
        elseif 0 < z # above
            z
        else # inside: -h <= z <= 0
            d = abs(y) - w/2
            d < 0 ? abs(x) - l/2 : d
        end
    end ~ call
end

@system Tropism begin
    N: tropsim_trials => 1.0 ~ preserve(parameter)
    to(; α, β): tropism_objective => 0 ~ call
end

@system Plagiotropism(Tropism) begin
    RT0: parent_transformation ~ hold
    to(RT0; α, β): tropism_objective => begin
        R = RotZX(β, α) |> LinearMap
        (RT0 ∘ R).linear[9] |> abs
    end ~ call
end

@system Gravitropism(Tropism) begin
    RT0: parent_transformation ~ hold
    to(RT0; α, β): tropism_objective => begin
        R = RotZX(β, α) |> LinearMap
        #-(RT0 ∘ R).linear[9]
        p = (RT0 ∘ R)([0, 0, -1])
        p[3]
    end ~ call
end

@system Exotropism(Tropism) begin
    to(; α, β): tropism_objective => begin
        #HACK: not exact implementation, needs to keep initial heading
        abs(Cropbox.deunitfy(α))
    end ~ call
end

abstract type RootSystem <: System end

@system BaseRoot(Tropism, Rendering) <: RootSystem begin
    box ~ ::ContainerSystem(override)

    ro: root_order => 1 ~ preserve::Int(extern)
    zi: zone_index => 0 ~ preserve::Int(extern)

    zt(lmax, la, lb, lp): zone_type => begin
        if (lmax - la) <= lp
            :apical
        elseif lp < lb
            :basal
        else
            :lateral
        end
    end ~ preserve::Symbol

    lb: length_of_basal_zone => 0.4 ~ preserve(u"cm", extern, parameter, min=0)
    la: length_of_apical_zone => 0.5 ~ preserve(u"cm", extern, parameter, min=0)
    ln: length_between_lateral_branches => 0.3 ~ preserve(u"cm", extern, parameter, min=0)
    lmax: maximal_length => 3.9 ~ preserve(u"cm", extern, parameter, min=0)

    zl(zt, lb, ln, la, lmax, lp): zone_length => begin
        l = if zt == :basal
            lb
        elseif zt == :apical
            la
        else
            ln
        end
    end ~ preserve(u"cm")

    r: maximum_elongation_rate => 1.0 ~ preserve(u"cm/d", extern, parameter, min=0)
    GD(lmax, r): growth_duration => begin
        d = lmax / r
        1.5d
    end ~ preserve(u"d")
    ea0: initial_elongation_age => 0 ~ preserve(u"d", extern)
    ea(l, Δx, lt, lmax): elongation_age => (l < Δx && lt < lmax ? 1 : 0) ~ accumulate(init=ea0, u"d")
    bg(t_b=0u"d", delta=1; t(u"d"), t_e(u"d"), c_m(u"cm/d")): beta_growth => begin
        t = clamp(t, zero(t), t_e)
        t_m = t_e / 2
        t_et = t_e - t
        t_em = t_e - t_m
        t_tb = t - t_b
        t_mb = t_m - t_b
        c_m * ((t_et / t_em) * (t_tb / t_mb)^(t_mb / t_em))^delta
    end ~ call(u"cm/d")
    pr(bg, ea, GD, r): potential_elongation_rate => bg(ea, GD, r) ~ track(u"cm/d")

    Δt(context.clock.step): timestep ~ preserve(u"hr")
    ar(pr, Δx, l, Δt): actual_elongation_rate => min(pr, (Δx - l) / Δt) ~ track(u"cm/d")
    rr(pr, ar): remaining_elongation_rate => pr - ar ~ track(u"cm/d")
    rl(rr, Δt): remaining_length => rr*Δt ~ track(u"cm")
    l0: initial_length => 0 ~ preserve(u"cm", extern)
    lp: parent_length => 0 ~ preserve(u"cm", extern)
    l(ar): length ~ accumulate(init=l0, u"cm")
    lt(lp, l): total_length => lp + l ~ track(u"cm")

    Δx: axial_resolution => 1 ~ preserve(u"cm", parameter)
    σ: standard_deviation_of_angle => 30 ~ preserve(u"°", parameter)
    σ_Δx(σ, nounit(Δx)): normalized_standard_deviation_of_angle => sqrt(Δx)*σ ~ track(u"°")

    θ: insertion_angle => 30 ~ preserve(u"°", parameter)
    pα(zi, nounit(θ), nounit(σ_Δx);): pick_angular_angle => begin
        θ = zi == 0 ? θ : zero(θ)
        rand(Normal(θ, σ_Δx))
    end ~ call(u"°")
    pβ(;): pick_radial_angle => rand(Uniform(0, 360)) ~ call(u"°")
    αN: angular_angle_trials => 20 ~ preserve::Int(parameter)
    βN: raidal_angle_trials => 5 ~ preserve::Int(parameter)
    A(pα, pβ, to, N, dist=box.dist, np, αN, βN): angles => begin
        n = rand() < N % 1 ? ceil(N) : floor(N)
        P = [(pα(), pβ()) for i in 0:n]
        O = [to(α, β) for (α, β) in P]
        (o, i) = findmin(O)
        (α, β) = P[i]
        d = dist(np(α, β))
        for i in 1:αN
            α1 = α + 90u"°" * (i-1)/αN
            for j in 1:βN
                d < 0 && break
                β1 = pβ()
                d1 = dist(np(α1, β1))
                if d1 < d
                    d = d1
                    α, β = α1, β1
                end
            end
            d < 0 && break
        end
        (α, β)
    end ~ preserve::Tuple
    α(A): angular_angle => A[1] ~ preserve(u"°")
    β(A): radial_angle => A[2] ~ preserve(u"°")

    RT0: parent_transformation ~ track::Transformation(override)
    pp(RT0): parent_position => RT0([0, 0, 0]) ~ preserve::Point3f0
    np(pp, RT0, nounit(Δx); α, β): new_position => begin
        R = RotZX(β, α) |> LinearMap
        pp + (RT0 ∘ R)([0, 0, -Δx])
    end ~ call::Point3f0
    RT(nounit(l), α, β): local_transformation => begin
        # put root segment at parent's end
        T = Translation(0, 0, -l)
        # rotate root segment
        R = RotZX(β, α) |> LinearMap
        R ∘ T
    end ~ track::Transformation
    RT1(RT0, RT): global_transformation => RT0 ∘ RT ~ track::Transformation
    cp(RT1): current_position => RT1([0, 0, 0]) ~ track::Point3f0

    a: radius => 0.05 ~ preserve(u"cm", parameter, min=0.01)

    c: color => RGBA(1, 1, 1, 1) ~ preserve::RGBA(parameter)

    n: name ~ hold
    T: transition ~ hold
    nb(T, name;): next_branch => begin
        find(r) = begin
            d = T[name]
            for (k, v) in d
                r < v ? (return k) : (r -= v)
            end
            :nothing
        end
        find(rand())
    end ~ call::Symbol

    ms(l, Δx, lt, lmax): may_segment => (l >= Δx && lt < lmax) ~ flag
    S(S, ms, n, box, ro, zi, r, ea, rl, lb, la, ln, lmax, lt, wrap(RT1)): segment => begin
        (isempty(S) && ms) ? [
            #HACK: keep lb/la/ln/lmax parameters same for consecutive segments
            produce(eval(n), box=box, ro=ro, zi=zi+1, r=r, ea0=ea, l0=rl, lb=lb, la=la, ln=ln, lmax=lmax, lp=lt, RT0=RT1),
        ] : nothing
    end ~ produce::BaseRoot

    mb(lt, zl, zt): may_branch => (lt >= zl && zt != :apical) ~ flag
    B(B, mb, nb, box, ro, wrap(RT1)): branch => begin
        (isempty(B) && mb) ? [
            #HACK: eval() for Symbol-based instantiation based on tabulate-d matrix
            produce(eval(nb()), box=box, ro=ro+1, RT0=RT1),
        ] : nothing
    end ~ produce::BaseRoot
end

#TODO: provide @macro / function to automatically build a series of related Systems
@system MyBaseRoot(BaseRoot) <: RootSystem begin
    T: transition ~ tabulate(rows=(:PrimaryRoot, :FirstOrderLateralRoot, :SecondOrderLateralRoot), parameter)
end
@system PrimaryRoot(MyBaseRoot, Gravitropism) <: RootSystem begin
    n: name => :PrimaryRoot ~ preserve::Symbol
end
@system FirstOrderLateralRoot(MyBaseRoot, Gravitropism) <: RootSystem begin
    n: name => :FirstOrderLateralRoot ~ preserve::Symbol
end
@system SecondOrderLateralRoot(MyBaseRoot, Tropism) <: RootSystem begin
    n: name => :SecondOrderLateralRoot ~ preserve::Symbol
end

@system RootArchitecture(Controller) begin
    box(context) ~ ::Rhizobox
    maxB: number_of_basal_roots => 1 ~ preserve::Int(parameter)
    RT0: initial_transformation => IdentityTransformation() ~ track::Transformation
    roots(roots, box, maxB, wrap(RT0)) => begin
        [produce(PrimaryRoot, box=box, RT0=RT0) for i in (length(roots)+1):maxB]
    end ~ produce::PrimaryRoot
end

render(s::System) = (vis = Visualizer(); render!(s, vis); vis)
#TODO: provide macro (i.e. @mixin/@drive?) for scaffolding functions based on traits (Val)
render!(s, vis) = render!(Cropbox.mixindispatch(s, Rendering)..., vis)
render!(V::Val{:Rendering}, r::RootSystem, vis) = begin
    l = Cropbox.deunitfy(r.l')
    a = Cropbox.deunitfy(r.a')
    (iszero(l) || iszero(a)) && return
    g = Cylinder3{Float32}(Point3f0(0), Point3f0(0, 0, l), a)
    M = r.RT'
    # add root segment
    cvis = vis["$(UUIDs.uuid1())"]
    ro = r.ro'
    c = r.color'
    m = MeshCat.defaultmaterial(color=c)
    setobject!(cvis, g, m)
    settransform!(cvis, M)
    # visit recursively
    render!(Val(nothing), r, cvis)
end
render!(::Val, s::System, vis) = render!.(Cropbox.value.(collect(s)), Ref(vis))
render!(::Val, V::Vector{<:System}, vis) = render!.(V, Ref(vis))
render!(::Val, s, vis) = nothing

gather(s::System) = (L = []; gather!(s, L); L)
gather!(s, L) = gather!(Cropbox.mixindispatch(s, BaseRoot)..., L)
gather!(V::Val{:BaseRoot}, r::RootSystem, L) = begin
    r.zi' == 0 && push!(L, [r.pp', r.cp', r.S["**"].cp'...])
    gather!(Val(nothing), r, L)
end
gather!(::Val, s::System, L) = gather!.(Cropbox.value.(collect(s)), Ref(L))
gather!(::Val, V::Vector{<:System}, L) = gather!.(V, Ref(L))
gather!(::Val, s, L) = nothing

using WriteVTK
gathervtk(name::AbstractString, s::System) = begin
    L = gather(s)
    P = Float32[]
    C = MeshCell[]
    i = 0
    for l in L
        [append!(P, p) for p in l]
        n = length(l)
        I = collect(1:n) .+ i
        i += n
        c = MeshCell(VTKCellTypes.VTK_POLY_LINE, I)
        push!(C, c)
    end
    P3 = reshape(P, 3, :)
    g = vtk_grid(name, P3, C)
end
writevtk(name::AbstractString, s::System) = vtk_save(gathervtk(name, s))
writepvd(name::AbstractString, S::Type{<:System}; kwargs...) = begin
    pvd = paraview_collection(name)
    path = mkpath("$name-pvd")
    i = 0
    simulate(S; kwargs...) do s
        pvd[i] = gathervtk("$path/$name-$i", s)
        i += 1
    end
    vtk_save(pvd)
end

end
