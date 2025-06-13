import dask.array as da
import time
from dask.core import get_dependencies
from collections import Counter
from dataclasses import dataclass
from typing import Hashable
import ray
import cloudpickle

ray.init()

# The type used to represent an iteration.
# A Dask array is identified by its name and a timestep.
Timestep = Hashable

@dataclass
class ChunkRef:
    """
    Represents a chunk of an array in a Dask task graph.

    The task corresping to this object must be scheduled by the actor who has the actual
    data. This class is used since Dask tends to inline simple tuples. This may change
    in newer versions of Dask.
    """

    actor_id: int
    array_name: str  # The real name, without the timestep
    timestep: Timestep
    position: tuple[int, ...]

    # Set for one chunk only.
    _all_chunks: "ray.ObjectRef | None" = None


n = 0

def do_computation():
    array = da.zeros(10_000, chunks=(1))
    mean_graph = array.mean()

    dsk = dict(mean_graph.dask)

    dsk = {
        k: v if get_dependencies(dsk, k) else ChunkRef(12, "my_array", 42, (1, 4))
        for k, v in dsk.items()
    }

    dsk = {k: v for k, v in sorted(dsk.items())}

    # print(len(cloudpickle.dumps(dsk)))

    scheduling = {k: -1 for k in dsk.keys()}

    key = list(dsk.items())[0][0]

    def explore(k) -> int:
        global n
        deps = get_dependencies(dsk, k)

        if not deps:
            n += 1
            scheduling[k] = 0
        else:
            res = [explore(dep) for dep in get_dependencies(dsk, k)]
            scheduling[k] = Counter(res).most_common(1)[0][0]

        return scheduling[k]

    explore(key)

    x = ray.put(dsk), ray.put(scheduling)
    return

compute_start = time.time()

for _ in range(10):
    do_computation()

compute_end = time.time()

print(f"Computation time: {(compute_end - compute_start) / 10:.4f} seconds")
print(n // 10)