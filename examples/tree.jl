using ActorInterfaces.Classic

struct Spawner end  # Actor behavior (and empty state)

struct SpawnTree # Command to spawn a tree of actors
    childcount::UInt8
    depth::UInt8
end

function Classic.onmessage(me::Actor{Spawner}, msg::SpawnTree)
    if msg.depth > 0
        for i = 1:msg.childcount
            child = spawn(me.addr.scheduler, Spawner())
            send(child, SpawnTree(msg.childcount, msg.depth - 1))
        end
    end
    return nothing
end

using Test
using QuickActors
import ActorInterfaces.Implementation.Tick # Just a test to see if scheduler lifecycle can also be standardized

const TREE_HEIGHT = 19
const TREE_SIZE = 2^(TREE_HEIGHT + 1) - 1

s = QuickScheduler()
rootaddr = spawn(s, Spawner())
send(rootaddr, SpawnTree(2, TREE_HEIGHT))
println("Building a tree of $TREE_SIZE actors and delivering the same amount of messages")
@time while Tick.tick!(s) end
@test length(s.actorcache) == TREE_SIZE
