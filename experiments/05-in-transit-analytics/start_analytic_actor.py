import sys

import ray
from ray.util.scheduling_strategies import NodeAffinitySchedulingStrategy

from doreisa.in_transit_analytic_actor import InTransitAnalyticActor

ray.init(address="auto")

actor = InTransitAnalyticActor.options(
    # Schedule the actor on this node
    scheduling_strategy=NodeAffinitySchedulingStrategy(
        node_id=ray.get_runtime_context().get_node_id(),
        soft=False,
    ),
    # Prevents the actor from being stuck when it needs to gather many refs
    max_concurrency=1000_000_000,
    # Disabled for performance reasons
    enable_task_events=False,
).remote()

print("Starting analytic actor on", sys.argv[1:])
ray.get([
    actor.run_zmq_server.remote(address)
    for address in sys.argv[1:]
])
