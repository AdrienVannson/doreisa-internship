import asyncio
import os
import time
import sys

import dask.array as da
import numpy as np
import ray

import doreisa.head_node as doreisa

exp_dir = os.path.dirname(os.path.realpath(__file__))
do_computation = bool(int(sys.argv[1]))

doreisa.init()

start_time = None

def simulation_callback(arrays: list[da.Array], timestep: int):
    arr = arrays[0]

    dsk = arr.mean()

    if do_computation:
        dsk.compute()

    if timestep == 20:
        global start_time
        start_time = time.time()

    if timestep == 120:
        end_time = time.time()

        with open(f"{exp_dir}/results.txt", "a") as f:
            f.write(f"{len(ray.nodes()) - 1} {np.prod(arr.numblocks)} do_computation={do_computation} {1000 * (end_time - start_time) / 100}\n")

asyncio.run(
    doreisa.start(
        simulation_callback,
        [
            doreisa.DaskArrayInfo("arrays", window_size=1),
        ],
    )
)
