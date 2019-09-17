using DataFrames
using TimeZones
using Unitful

@testset "system" begin
    @testset "derive" begin
        @system SDerive begin
            a => 1 ~ track
            b => 2 ~ track
            c(a, b) => a + b ~ track
        end
        s = instance(SDerive)
        @test s.a == 1 && s.b == 2 && s.c == 3
    end

    @testset "derive with cross reference" begin
        @test_throws LoadError @eval @system SDeriveXRef begin
            a(b) => b ~ track
            b(a) => a ~ track
        end
    end

    @testset "call" begin
        @system SCall begin
            fa(; x) => x ~ call
            a(fa) => fa(1) ~ track
            fb(i; x) => i + x ~ call
            b(fb) => fb(1) ~ track
            i => 1 ~ preserve
        end
        s = instance(SCall)
        @test s.a == 1
        @test s.b == 2
    end

    @testset "call with unit" begin
        @system SCallUnit begin
            fa(; x(u"m")) => x ~ call(u"m")
            a(fa) => fa(1u"m") ~ track(u"m")
            fb(i; x(u"m")) => i + x ~ call(u"m")
            b(fb) => fb(1u"m") ~ track(u"m")
            i => 1 ~ preserve(u"m")
        end
        s = instance(SCallUnit)
        @test s.a == 1u"m"
        @test s.b == 2u"m"
    end

    @testset "call with type and unit" begin
        @system SCallTypeUnit begin
            fa(; x::Int(u"m")) => x ~ call::Int(u"m")
            a(fa) => fa(1u"m") ~ track::Int(u"m")
            fb(i; x::Int(u"m")) => i + x ~ call::Int(u"m")
            b(fb) => fb(1u"m") ~ track::Int(u"m")
            i => 1 ~ preserve::Int(u"m")
        end
        s = instance(SCallTypeUnit)
        @test s.a == 1u"m"
        @test s.b == 2u"m"
        @test Cropbox.value(s.a) |> ustrip |> typeof == Int
        @test Cropbox.value(s.b) |> ustrip |> typeof == Int
    end

    @testset "accumulate" begin
        @system SAccumulate begin
            a => 1 ~ track
            b(a) => a + 1 ~ accumulate
        end
        s = instance(SAccumulate)
        @test s.a == 1 && s.b == 0
        advance!(s)
        @test s.a == 1 && s.b == 2
        advance!(s)
        @test s.a == 1 && s.b == 4
        advance!(s)
        @test s.a == 1 && s.b == 6
    end

    @testset "accumulate with cross reference" begin
        @system SAccumulateXRef begin
            a(b) => b + 1 ~ accumulate
            b(a) => a + 1 ~ accumulate
        end
        s = instance(SAccumulateXRef)
        @test s.a == 0 && s.b == 0
        advance!(s)
        @test s.a == 1 && s.b == 1
        advance!(s)
        @test s.a == 3 && s.b == 3
        advance!(s)
        @test s.a == 7 && s.b == 7
    end

    @testset "accumulate with cross reference mirror" begin
        @system SAccumulateXrefMirror1 begin
            a(b) => b + 1 ~ accumulate
            b(a) => a + 2 ~ accumulate
        end
        @system SAccumulateXrefMirror2 begin
            a(b) => b + 2 ~ accumulate
            b(a) => a + 1 ~ accumulate
        end
        s1 = instance(SAccumulateXrefMirror1); s2 = instance(SAccumulateXrefMirror2)
        @test s1.a == 0 == s2.b && s1.b == 0 == s2.a
        advance!(s1); advance!(s2)
        @test s1.a == 1 == s2.b && s1.b == 2 == s2.a
        advance!(s1); advance!(s2)
        @test s1.a == 4 == s2.b && s1.b == 5 == s2.a
        advance!(s1); advance!(s2)
        @test s1.a == 10 == s2.b && s1.b == 11 == s2.a
    end

    @testset "accumulate with time" begin
        @system SAccumulateTime begin
            t(x=context.clock.tick) => 0.5x ~ track(u"hr")
            a => 1 ~ track
            b(a) => a + 1 ~ accumulate
            c(a) => a + 1 ~ accumulate(time=t)
        end
        s = instance(SAccumulateTime)
        @test s.a == 1 && s.b == 0 && s.c == 0
        advance!(s)
        @test s.a == 1 && s.b == 2 && s.c == 1
        advance!(s)
        @test s.a == 1 && s.b == 4 && s.c == 2
        advance!(s)
        @test s.a == 1 && s.b == 6 && s.c == 3
    end

    @testset "accumulate transport" begin
        @system SAccumulateTransport begin
            a(a, b) => -max(a - b, 0) ~ accumulate(init=10)
            b(a, b, c) => max(a - b, 0) - max(b - c, 0) ~ accumulate
            c(b, c) => max(b - c, 0) ~ accumulate
        end
        s = instance(SAccumulateTransport)
        @test s.a == 10 && s.b == 0 && s.c == 0
        advance!(s)
        @test s.a == 0 && s.b == 10 && s.c == 0
        advance!(s)
        @test s.a == 0 && s.b == 0 && s.c == 10
        advance!(s)
        @test s.a == 0 && s.b == 0 && s.c == 10
    end

    @testset "accumulate distribute" begin
        @system SAccumulateDistribute begin
            s(x=context.clock.tick) => (100u"hr^-1" * x) ~ track
            d1(s) => 0.2s ~ accumulate
            d2(s) => 0.3s ~ accumulate
            d3(s) => 0.5s ~ accumulate
        end
        s = instance(SAccumulateDistribute)
        c = s.context
        @test c.clock.tick == 1u"hr" && s.s == 100 && s.d1 == 0 && s.d2 == 0 && s.d3 == 0
        advance!(s)
        @test c.clock.tick == 2u"hr" && s.s == 200 && s.d1 == 20 && s.d2 == 30 && s.d3 == 50
        advance!(s)
        @test c.clock.tick == 3u"hr" && s.s == 300 && s.d1 == 60 && s.d2 == 90 && s.d3 == 150
        advance!(s)
        @test c.clock.tick == 4u"hr" && s.s == 400 && s.d1 == 120 && s.d2 == 180 && s.d3 == 300
    end

    @testset "capture" begin
        @system SCapture begin
            a => 1 ~ track
            b(a) => a + 1 ~ capture
            c(a) => a + 1 ~ accumulate
        end
        s = instance(SCapture)
        @test s.b == 0 && s.c == 0
        advance!(s)
        @test s.b == 2 && s.c == 2
        advance!(s)
        @test s.b == 2 && s.c == 4
    end

    @testset "capture with time" begin
        @system SCaptureTime begin
            t(x=context.clock.tick) => 2x ~ track(u"hr")
            a => 1 ~ track
            b(a) => a + 1 ~ capture(time=t)
            c(a) => a + 1 ~ accumulate(time=t)
        end
        s = instance(SCaptureTime)
        @test s.b == 0 && s.c == 0
        advance!(s)
        @test s.b == 4 && s.c == 4
        advance!(s)
        @test s.b == 4 && s.c == 8
    end

    @testset "preserve" begin
        @system SPreserve begin
            a => 1 ~ track
            b(a) => a + 1 ~ accumulate
            c(b) => b ~ preserve
        end
        s = instance(SPreserve)
        @test s.a == 1 && s.b == 0 && s.c == 0
        advance!(s)
        @test s.a == 1 && s.b == 2 && s.c == 0
    end

    @testset "parameter" begin
        @system SParameter begin
            a => 1 ~ preserve(parameter)
        end
        s = instance(SParameter)
        @test s.a == 1
        advance!(s)
        @test s.a == 1
    end

    @testset "parameter with config" begin
        @system SParameterConfig begin
            a => 1 ~ preserve(parameter)
        end
        o = configure(SParameterConfig => (:a => 2))
        s = instance(SParameterConfig; config=o)
        @test s.a == 2
    end

    @testset "parameter with config alias" begin
        @system SParameterConfigAlias begin
            a: aa => 1 ~ preserve(parameter)
            bb: b => 1 ~ preserve(parameter)
        end
        o = configure(SParameterConfigAlias => (:a => 2, :b => 2))
        s = instance(SParameterConfigAlias; config=o)
        @test s.a == 2
        @test s.b == 2
    end

    @testset "drive with dict" begin
        @system SDriveDict begin
            a(t=context.clock.tick) => Dict(:a => 10t) ~ drive(u"hr")
        end
        s = instance(SDriveDict)
        @test s.context.clock.tick == 1u"hr" && s.a == 10u"hr"
        advance!(s)
        @test s.context.clock.tick == 2u"hr" && s.a == 20u"hr"
    end

    @testset "drive with key" begin
        @system SDriveKey begin
            a => Dict(:b => 1) ~ drive(key=:b)
        end
        s = instance(SDriveKey)
        @test s.a == 1
    end

    @testset "drive with dataframe" begin
        @system SDriveDataFrame begin
            df => DataFrame(t=(0:4)u"hr", a=0:10:40) ~ preserve::DataFrame(static)
            a(df, t=context.clock.tick) => df[df.t .== t, :][1, :] ~ drive
        end
        s = instance(SDriveDataFrame)
        @test s.context.clock.tick == 1u"hr" && s.a == 10
        advance!(s)
        @test s.context.clock.tick == 2u"hr" && s.a == 20
    end

    @testset "flag" begin
        @system SFlag begin
            a => true ~ flag
            b => false ~ flag
        end
        s = instance(SFlag)
        @test s.a == true && s.b == false
    end

    @testset "produce" begin
        @system SProduce begin
            a => produce(SProduce) ~ produce
        end
        s = instance(SProduce)
        @test length(s.a) == 0
        advance!(s)
        @test length(s.a) == 1
        @test length(s.a[1].a) == 0
        advance!(s)
        @test length(s.a) == 2
        @test length(s.a[1].a) == 1
        @test length(s.a[2].a) == 0
    end

    @testset "produce with kwargs" begin
        @system SProduceKwargs begin
            a => produce(SProduceKwargs) ~ produce
            i(t=context.clock.tick) => t ~ preserve(u"hr")
        end
        s = instance(SProduceKwargs)
        @test length(s.a) == 0 && s.i == 0u"hr"
        advance!(s)
        @test length(s.a) == 1 && s.i == 0u"hr"
        @test length(s.a[1].a) == 0 && s.a[1].i == 1u"hr"
        advance!(s)
        @test length(s.a) == 2 && s.i == 0u"hr"
        @test length(s.a[1].a) == 1 && s.a[1].i == 1u"hr"
        @test length(s.a[2].a) == 0 && s.a[2].i == 2u"hr"
        @test length(s.a[1].a[1].a) == 0 && s.a[1].a[1].i == 2u"hr"
    end

    @testset "produce with nothing" begin
        @system SProduceNothing begin
            a => nothing ~ produce
        end
        s = instance(SProduceNothing)
        @test length(s.a) == 0
        advance!(s)
        @test length(s.a) == 0
    end

    @testset "produce query index" begin
        @system SProduceQueryIndex begin
            p => produce(SProduceQueryIndex) ~ produce
            i(t=context.clock.tick) => Int(ustrip(t)) ~ preserve::Int
            a(x=p["*"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            b(x=p["**"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            c(x=p["*/1"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            d(x=p["*/-1"].i) => (isempty(x) ? 0 : sum(x)) ~ track
        end
        s = instance(SProduceQueryIndex)
        @test length(s.p) == 0
        advance!(s)
        @test length(s.p) == 1
        @test s.a == 1 # (1)
        @test s.b == 1 # (1)
        @test s.c == 1 # (1*)
        @test s.d == 1 # (1*)
        advance!(s)
        @test length(s.p) == 2
        @test s.a == 3 # (1 + 2)
        @test s.b == 5 # ((1 ~ 2) + 2)
        @test s.c == 1 # (1* + 2)
        @test s.d == 2 # (1 + 2*)
        advance!(s)
        @test length(s.p) == 3
        @test s.a == 6 # (1 + 2 + 3)
        @test s.b == 17 # ((1 ~ ((2 ~ 3) + 3) + (2 ~ 3) + 3)
        @test s.c == 1 # (1* + 2 + 3)
        @test s.d == 3 # (1 + 2 + 3*)
    end

    @testset "produce query condition with track bool" begin
        @system SProduceQueryConditionTrackBool begin
            p => produce(SProduceQueryConditionTrackBool) ~ produce
            i(t=context.clock.tick) => Int(ustrip(t)) ~ preserve::Int
            f(i) => isodd(i) ~ track::Bool
            a(x=p["*/f"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            b(x=p["**/f"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            c(x=p["*/f/1"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            d(x=p["*/f/-1"].i) => (isempty(x) ? 0 : sum(x)) ~ track
        end
        s = instance(SProduceQueryConditionTrackBool)
        @test length(s.p) == 0
        advance!(s)
        @test length(s.p) == 1
        @test s.a == 1 # (#1)
        @test s.b == 1 # (#1)
        @test s.c == 1 # (#1*)
        @test s.d == 1 # (#1*)
        advance!(s)
        @test length(s.p) == 2
        @test s.a == 1 # (#1 + 2)
        @test s.b == 1 # (#1 ~ 2) + 2)
        @test s.c == 1 # (#1* + 2)
        @test s.d == 1 # (#1* + 2)
        advance!(s)
        @test length(s.p) == 3
        @test s.a == 4 # (#1 + 2 + #3)
        @test s.b == 13 # ((#1 ~ ((2 ~ #3) + #3) + (2 ~ #3) + #3)
        @test s.c == 1 # (1* + 2 + 3)
        @test s.d == 3 # (1 + 2 + #3*)
        advance!(s)
        @test length(s.p) == 4
        @test s.a == 4 # (#1 + 2 + #3 + 4)
        @test s.b == 13 # ((#1 ~ (2 ~ (#3 ~ 4)) + (#3 ~ 4) + 4) + (2 ~ (#3 ~ 4)) + (#3 ~ 4) + 4)
        @test s.c == 1 # (#1* + 2 + #3 + 4)
        @test s.d == 3 # (#1 + 2 + #3* + 4)
    end

    @testset "produce query condition with flag" begin
        @system SProduceQueryConditionFlag begin
            p => produce(SProduceQueryConditionFlag) ~ produce
            i(t=context.clock.tick) => Int(ustrip(t)) ~ preserve::Int
            f(i) => isodd(i) ~ flag
            a(x=p["*/f"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            b(x=p["**/f"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            c(x=p["*/f/1"].i) => (isempty(x) ? 0 : sum(x)) ~ track
            d(x=p["*/f/-1"].i) => (isempty(x) ? 0 : sum(x)) ~ track
        end
        s = instance(SProduceQueryConditionFlag)
        @test length(s.p) == 0
        advance!(s)
        @test length(s.p) == 1
        @test s.a == 0 # (.1)
        @test s.b == 0 # (.1)
        @test s.c == 0 # (.1*)
        @test s.d == 0 # (.1*)
        advance!(s)
        @test length(s.p) == 2
        @test s.a == 1 # (#1 + .2)
        @test s.b == 1 # (#1 ~ .2) + .2)
        @test s.c == 1 # (#1* + .2)
        @test s.d == 1 # (#1* + .2)
        advance!(s)
        @test length(s.p) == 3
        @test s.a == 1 # (#1 + 2 + .3)
        @test s.b == 1 # ((#1 ~ ((2 ~ .3) + .3) + (2 ~ .3) + .3)
        @test s.c == 1 # (#1* + 2 + .3)
        @test s.d == 1 # (#1* + 2 + .3)
        advance!(s)
        @test length(s.p) == 4
        @test s.a == 4 # (#1 + 2 + #3 + .4)
        @test s.b == 13 # ((#1 ~ (2 ~ (#3 ~ .4)) + (#3 ~ .4) + .4) + (2 ~ (#3 ~ .4)) + (#3 ~ .4) + .4)
        @test s.c == 1 # (#1* + 2 + #3 + .4)
        @test s.d == 3 # (#1 + 2 + #3* + .4)
    end

    @testset "solve bisect" begin
        @system SolveBisect begin
            x(x) => 2x - 1 ~ solve(lower=0, upper=2)
        end
        s = instance(SolveBisect)
        @test s.x == 1
    end

    # @testset "solve order0" begin
    #     @system SolveOrder0 begin
    #         x(x) => ((x^2 + 1) / 2) ~ solve
    #     end
    #     s = instance(SolveOrder0)
    #     @test isapprox(Cropbox.value(s.x), 1; atol=1e-3)
    # end

    @testset "solve bisect with unit" begin
        @system SolveBisectUnit begin
            x(x) => 2x - u"1m" ~ solve(lower=u"0m", upper=u"2m", u"m")
        end
        s = instance(SolveBisectUnit)
        @test s.x == u"1m"
    end

    @testset "clock" begin
        @system SClock begin
        end
        s = instance(SClock)
        # after one advance! in instance()
        @test s.context.clock.tick == 1u"hr"
        advance!(s)
        @test s.context.clock.tick == 2u"hr"
    end

    @testset "clock with config" begin
        @system SClockConfig begin
        end
        o = configure(:Clock => (#=:init => 5,=# step => 10))
        s = instance(SClockConfig; config=o)
        # after one advance! in instance()
        @test s.context.clock.tick == 10u"hr"
        advance!(s)
        @test s.context.clock.tick == 20u"hr"
    end

    @testset "calendar" begin
        t0 = ZonedDateTime(2011, 10, 29, tz"Asia/Seoul")
        o = configure(:Calendar => (:init => t0))
        s = instance(Calendar; config=o)
        # after one advance! in instance()
        @test s.init == t0
        @test s.time == ZonedDateTime(2011, 10, 29, 1, tz"Asia/Seoul")
        advance!(s)
        @test s.time == ZonedDateTime(2011, 10, 29, 2, tz"Asia/Seoul")
    end

    @testset "alias" begin
        @system SAlias begin
            a: aa => 1 ~ track
            b: [bb, bbb] => 2 ~ track
            c(a, aa, b, bb, bbb) => a + aa + b + bb + bbb ~ track
        end
        s = instance(SAlias)
        @test s.a == 1 == s.aa
        @test s.b == 2 == s.bb == 2 == s.bbb
        @test s.c == 8
    end

    @testset "single arg without key" begin
        @system SSingleArgWithoutKey begin
            a => 1 ~ track
            b(a) ~ track
            c(x=a) ~ track
        end
        s = instance(SSingleArgWithoutKey)
        @test s.a == 1
        @test s.b == 1
        @test s.c == 1
    end
end
