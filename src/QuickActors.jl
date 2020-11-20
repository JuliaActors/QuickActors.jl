module QuickActors

export QuickActor, QuickAddr, QuickScheduler, run!, send!, spawn!

using ActorInterfaces.Classic
using ActorInterfaces.Implementation
using ActorInterfaces.Implementation.Tick

struct QuickAddr <: Addr
    id::UInt64
end
Classic.SendStyle(::Type{QuickAddr}) = Sendable()

struct QuickActor{TBehavior, TScheduler <: Scheduler} <: Actor{TBehavior}
    addr::QuickAddr
    scheduler::TScheduler
    behavior::TBehavior
end

function QuickActor(behavior, scheduler)
    return QuickActor{typeof(behavior), typeof(scheduler)}(gen_addr(), scheduler, behavior)
end

gen_addr() = QuickAddr(rand(UInt64))

Classic.behavior(actor::QuickActor) = actor.behavior
Classic.addr(actor::QuickActor) = actor.addr

struct Envelope{TMsg <: Any} 
    to::QuickAddr
    msg::TMsg
end

struct QuickScheduler <: Implementation.Scheduler
    actorcache::Dict{QuickAddr, QuickActor}
    msgs::Array{Envelope}
    QuickScheduler() = new(Dict(), [])
end

function Tick.tick!(sdl::QuickScheduler)::Bool
    isempty(sdl.msgs) && return false
    envelope = popfirst!(sdl.msgs)
    actor = get!(sdl.actorcache, envelope.to, nothing)
    isnothing(actor) && error("Actor with address $(msg.to) not scheduled.")
    deliver!(actor, envelope.msg)
    return true
end

function deliver!(actor::QuickActor, msg)
    if SendStyle(typeof(msg)) == Racing()
        onmessage(actor, msg, Racing())
    else
        onmessage(actor, msg)
    end
end

function send!(sdl::QuickScheduler, target::QuickAddr, msg, ::Union{Sendable, Racing})
    push!(sdl.msgs, Envelope(target, msg))
    return nothing
end
send!(sdl::QuickScheduler, target::Addr, msg) = send!(sdl, target, msg, SendStyle(typeof(msg)))

function spawn!(sdl::QuickScheduler, behavior)
    actor = QuickActor(behavior, sdl)
    sdl.actorcache[actor.addr] = actor
    return actor.addr
end

function Classic.send(sender::QuickActor, target::QuickAddr, msg, ::Union{Sendable, Racing})
    send!(sender.scheduler, target, msg)
end

Classic.spawn(spawner::QuickActor, behavior) = spawn!(spawner.scheduler, behavior)

function Classic.become(source::QuickActor, target)
    sdl = source.scheduler
    sdl.actorcache[addr(source)] = QuickActor(addr(source), sdl, target)
end

end # module QuickActors