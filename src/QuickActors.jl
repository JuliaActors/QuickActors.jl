module QuickActors

export QuickActor, QuickAddr, QuickScheduler

using ActorInterfaces.Classic
using ActorInterfaces.Implementation
using ActorInterfaces.Implementation.Tick

struct QuickAddr{TScheduler <: Context} <: Addr
    id::UInt64
    scheduler::TScheduler
end

struct QuickActor{TBehavior} <: Actor{TBehavior}
    addr::QuickAddr
    behavior::TBehavior
end

QuickActor(behavior, scheduler) = QuickActor{typeof(behavior)}(gen_addr(scheduler), behavior)

gen_addr(scheduler) = QuickAddr(rand(UInt64), scheduler)

# Classic.behavior(actor::QuickActor) = actor.behavior
# Classic.addr(actor::QuickActor) = actor.addr

struct Envelope{TMsg <: Any} 
    to::QuickAddr
    msg::TMsg
end

mutable struct QuickScheduler <: Implementation.Context
    task::Task
    actorcache::Dict{QuickAddr, QuickActor}
    msgs::Array{Envelope}
    now::Union{Nothing,QuickActor}
end
QuickScheduler() = task_local_storage(:qs, QuickScheduler(current_task(), Dict(), [], nothing))

Classic.context() = task_local_storage(:qs)

Classic.self() = context().now.addr

function Tick.tick!(sdl::QuickScheduler)::Bool
    isempty(sdl.msgs) && return false
    envelope = popfirst!(sdl.msgs)
    sdl.now = get!(sdl.actorcache, envelope.to, nothing)
    isnothing(sdl.now) && error("Actor with address $(msg.to) not scheduled.")
    deliver!(sdl.now, envelope.msg)
    return true
end

# run!(sdl::QuickScheduler) = while tick!(sdl) end

deliver!(actor::QuickActor, msg) = onmessage(actor, msg)

function Classic.send(target::QuickAddr, msg)
    push!(target.scheduler.msgs, Envelope(target, msg))
    return nothing
end

function Classic.spawn(context, behavior)
    actor = QuickActor(behavior, context)
    context.actorcache[actor.addr] = actor
    return actor.addr
end
Classic.spawn(behavior) = spawn(context(), behavior)

function Classic.become(target)
    sdl = context()
    sdl.actorcache[sdl.now.addr] = QuickActor{typeof(target)}(sdl.now.addr, target)
end

end # module QuickActors