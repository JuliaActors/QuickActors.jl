module QuickActors

export QuickActor, QuickAddr, QuickScheduler, run!, send!, spawn!

using ActorInterfaces.Classic
using ActorInterfaces.Implementation
using ActorInterfaces.Implementation.Tick

struct QuickAddr <: Addr
    id::UInt64
end
# Classic.SendStyle(::Type{QuickAddr}) = Sendable()

struct Envelope{TMsg <: Any} 
    to::QuickAddr
    msg::TMsg
end

struct QuickScheduler <: Implementation.Scheduler
    actorcache::Dict{QuickAddr, Any}
    msgs::Array{Envelope}
    QuickScheduler() = new(Dict(), [])
end

struct QuickActor{TBehavior}
    addr::QuickAddr
    behavior::TBehavior
end

function QuickActor(behavior)
    return QuickActor{typeof(behavior)}(gen_addr(), behavior)
end
gen_addr() = QuickAddr(rand(UInt64))

struct ActorContext{TActor}
    scheduler::QuickScheduler
    actor::TActor
end

Classic.self(;ctx::ActorContext) = ctx.actor.addr

function Tick.tick!(sdl::QuickScheduler)::Bool
    isempty(sdl.msgs) && return false
    envelope = popfirst!(sdl.msgs)
    ctx = get!(sdl.actorcache, envelope.to, nothing)
    isnothing(ctx) && error("Actor with address $(msg.to) not scheduled.")
    deliver!(ctx, envelope.msg)
    return true
end

function deliver!(ctx, msg)
    ctx.actor.behavior(msg; ctx)
end

function send!(sdl::QuickScheduler, target::QuickAddr, msg)
    push!(sdl.msgs, Envelope(target, msg))
    return nothing
end
# send!(sdl::QuickScheduler, target::Addr, msg) = send!(sdl, target, msg, SendStyle(typeof(msg)))

function spawn!(sdl::QuickScheduler, behavior)
    actor = QuickActor(behavior)
    sdl.actorcache[actor.addr] = ActorContext(sdl, actor)
    return actor.addr
end

function Classic.send(target::QuickAddr, msg; ctx::ActorContext)
    send!(ctx.scheduler, target, msg)
end

Classic.spawn(behavior; ctx::ActorContext) = spawn!(ctx.scheduler, behavior)

function Classic.become(target; ctx::ActorContext)
    sdl = ctx.scheduler
    actor = QuickActor(self(;ctx), target)
    sdl.actorcache[self(;ctx)] = ActorContext(sdl, actor)
end

end # module QuickActors