# QuickActors.jl

![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)
<!--
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://tisztamo.github.io/QuickActors.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-master-blue.svg)](https://tisztamo.github.io/QuickActors.jl/dev)
-->

This package is the reference implementation of [ActorInterfaces.Classic](https://juliaactors.github.io/ActorInterfaces.jl/dev/reference/#ActorInterfaces.Classic).
Its main purpose is to demonstrate the semantics and implementability of the interface.

QuickActors.jl is also an usable - albeit limited - actor library: A fast, single threaded, deterministic, minimalist implementation that can be used during local development or testing of actor code.

The stack example of Agha implemented directly in ActorInterfaces:

```
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

@ctx function Classic.onmessage(me::Forwarder, msg)
    send(me.target, msg)
end

@ctx function Classic.onmessage(me::StackNode, msg::Push)
    p = spawn(StackNode(me.content, me.link))
    become(StackNode(msg.content, p))
end

@ctx function Classic.onmessage(me::StackNode, msg::Pop)
    if !isnothing(me.link)
        become(Forwarder(me.link))
    end
    send(msg.customer, me.content)
end
```

Running it with QuickActors.jl:

```
using QuickActors
using Test
import ActorInterfaces.Implementation.Tick

struct TestCoordinator
    received::Vector{Any}
end

@ctx function Classic.onmessage(me::TestCoordinator, msg)
    push!(me.received, msg)
end

s = QuickScheduler()
stack = StackNode(nothing, nothing)
stackaddr = spawn!(s, stack)
coordinator = TestCoordinator([])
coordaddr = spawn!(s, coordinator)
send!(s, stackaddr, Push(42))
send!(s, stackaddr, Push(43))
send!(s, stackaddr, Pop(coordaddr))

while Tick.tick!(s) end # Run the scheduler "manually" to process the messages

@test coordinator.received == Any[43]
send!(s, stackaddr, Pop(coordaddr))
while Tick.tick!(s) end
@test coordinator.received == Any[43, 42]
```

To communicate with the stack we had to create an extra actor, `TestCoordinator`. In `QuickActors.jl` currently we can send messages from the outside into the actor system, but it is not possible to receive responses directly. Only actors can receive messages.

You can find more examples in the [tests](https://github.com/JuliaActors/QuickActors.jl/tree/main/test)