using ActorInterfaces.Classic

struct Pop
    customer::Addr
end

struct Push
    content
end

struct StackNode
    content
    link::Union{Addr, Nothing}
end

struct Forwarder
    target::Addr
end

@ctx function (me::Forwarder)(msg)
    send(me.target, msg)
end

@ctx function (me::StackNode)(msg::Push)
    p = spawn(StackNode(me.content, me.link))
    become(StackNode(msg.content, p))
end

@ctx function (me::StackNode)(msg::Pop)
    if !isnothing(me.link)
        become(Forwarder(me.link))
    end
    send(msg.customer, me.content)
end

using QuickActors
using Test
import ActorInterfaces.Implementation.Tick

struct TestCoordinator
    received::Vector{Any}
end

@ctx function (me::TestCoordinator)(msg)
    push!(me.received, msg)
end

@testset "Stack" begin
    s = QuickScheduler()
    stack = StackNode(nothing, nothing)
    stackaddr = spawn!(s, stack)
    coordinator = TestCoordinator([])
    coordaddr = spawn!(s, coordinator)
    send!(s, stackaddr, Push(42))
    send!(s, stackaddr, Push(43))
    while Tick.tick!(s) end
    @test length(coordinator.received) == 0
    send!(s, stackaddr, Pop(coordaddr))
    while Tick.tick!(s) end
    @test coordinator.received == Any[43]
    send!(s, stackaddr, Pop(coordaddr))
    while Tick.tick!(s) end
    @test coordinator.received == Any[43, 42]
    send!(s, stackaddr, Pop(coordaddr))
    while Tick.tick!(s) end
    @test coordinator.received == Any[43, 42, nothing]
    send!(s, stackaddr, Pop(coordaddr))
    while Tick.tick!(s) end
    @test coordinator.received == Any[43, 42, nothing, nothing]
end