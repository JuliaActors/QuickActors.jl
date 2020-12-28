using ActorInterfaces.Classic
using ActorInterfacesTests
using QuickActors
import ActorInterfaces.Implementation.Tick

struct QuickActorsWrapper <: ActorInterfacesTests.ActorLib
    s::QuickScheduler
    QuickActorsWrapper() = new(QuickScheduler())
end

function ActorInterfacesTests.ex_spawn!(lib::QuickActorsWrapper, bhv, args...)
    return spawn!(lib.s, bhv, args...)
end

function ActorInterfacesTests.ex_send!(lib::QuickActorsWrapper, addr::Addr, msg...)
    return send!(lib.s, addr, msg...)
end

function ActorInterfacesTests.ex_actorcount(lib::QuickActorsWrapper)
    return length(lib.s.actorcache)
end

function ActorInterfacesTests.ex_runtofinish(lib::QuickActorsWrapper)
    while Tick.tick!(lib.s) end
    return nothing
end

run_suite(QuickActorsWrapper)