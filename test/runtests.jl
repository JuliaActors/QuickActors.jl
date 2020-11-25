using ActorInterfaces.Classic
using QuickActors
import ActorInterfaces.Implementation.Tick
using Test

abstract type MyMessage end
#Classic.SendStyle(::Type{<:MyMessage}) = Sendable()

mutable struct Counter
    counter::Int
end

struct Increment <: MyMessage end

@actor function Classic.onmessage(me::Counter, ::Increment)
    me.counter += 1
end

struct Spawner end

struct SpawnTree <: MyMessage
    childcount::UInt8
    depth::UInt8
end

@actor function Classic.onmessage(me::Spawner, msg::SpawnTree)
    if msg.depth > 0
        for i = 1:msg.childcount
            child = spawn(Spawner())
            send(child, SpawnTree(msg.childcount, msg.depth - 1))
        end
    end
    return nothing
end

# struct NoMessage end

# mutable struct RaceTester
#     arrived::Bool
#     RaceTester() = new(false)
# end
# struct RacingMessage end
# Classic.SendStyle(::Type{RacingMessage}) = Racing()

# function Classic.onmessage(me::Actor{RaceTester}, msg::RacingMessage, ::Racing)
#     behavior(me).arrived = true
# end
# function Classic.onmessage(me::Actor{RaceTester}, msg::RacingMessage)
#     error("Invalid delivery of Racing!")
# end

@testset "Empty Scheduler" begin
    s = QuickScheduler()
    @test isempty(s.msgs)
    @test isempty(s.actorcache)
    while Tick.tick!(s) end
    @test isempty(s.msgs)
    @test isempty(s.actorcache)
end

@testset "Spawning from the outside" begin
    s = QuickScheduler()
    counter = Counter(0)
    counteraddr = spawn!(s, counter)
    @test length(s.actorcache) == 1
    @test counteraddr isa Addr
    @test isempty(s.msgs)
end

@testset "Sending messages from the outside" begin
    s = QuickScheduler()
    counter = Counter(0)
    counteraddr = spawn!(s, counter)
    send!(s, counteraddr, Increment())
    @test counter.counter == 0
    @test !isempty(s.msgs)
    while Tick.tick!(s) end
    @test counter.counter == 1
    @test isempty(s.msgs)
    send!(s, counteraddr, Increment())
    send!(s, counteraddr, Increment())
    send!(s, counteraddr, Increment())
    while Tick.tick!(s) end
    @test counter.counter == 4
end

const TREE_HEIGHT = 19
const TREE_SIZE = 2^(TREE_HEIGHT + 1) - 1

@testset "Tree: Spawning children and sending messages to them" begin
    s = QuickScheduler()
    root = Spawner()
    rootaddr = spawn!(s, root)
    send!(s, rootaddr, SpawnTree(2, TREE_HEIGHT))
    println("Building a tree of $TREE_SIZE actors and delivering the same amount of messages")
    @time while Tick.tick!(s) end
    @test length(s.actorcache) == TREE_SIZE
end

# @testset "Sending NonSendable" begin
#     s = QuickScheduler()
#     root = Spawner()
#     rootaddr = spawn!(s, root)
#     @test_throws Classic.SendingNonSendable send(s.actorcache[rootaddr], rootaddr, NoMessage())
# end

# @testset "Sending Racing" begin
#     s = QuickScheduler()
#     tester = RaceTester()
#     testeraddr = spawn!(s, tester)
#     send!(s, testeraddr, RacingMessage())
#     while Tick.tick!(s) end
#     @test tester.arrived == true
# end

struct BecamePinger
    depth::Int
end

struct BecamePonger
    depth::Int
end

struct BecamePing <: MyMessage end
struct BecamePong <: MyMessage end

@actor function Classic.onmessage(me::BecamePinger, msg::BecamePong)
    depth = me.depth
    if depth > 0
        become(BecamePonger(depth))
        send(self(), BecamePing())
    end
    return nothing
end

@actor function Classic.onmessage(me::BecamePonger, msg::BecamePing)
    depth = me.depth
    if depth > 0
        become(BecamePinger(depth - 1))
        send(self(), BecamePong())
    end
    return nothing
end

const PING_COUNT = 5_00_000

@testset "Became" begin
    s = QuickScheduler()
    becamer = BecamePinger(PING_COUNT)
    becameraddr = spawn!(s, becamer)
    send!(s, becameraddr, BecamePong())
    println("Becoming $(PING_COUNT * 2) times to a different type and delivering the same amount of messages")
    @time while Tick.tick!(s) end
    @test s.actorcache[becameraddr].actor.behavior.depth == 0
end
