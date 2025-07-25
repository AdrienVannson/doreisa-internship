import time
import os
import random

import dask.array as da
import numpy as np
import ray

from doreisa.head_node import init
from doreisa.window_api import ArrayDefinition, run_simulation

exp_dir = os.path.dirname(os.path.realpath(__file__))

init()

start_time = None

# Unique ID for this simulation
uuid = str(random.randint(0, 2**128 - 1)).zfill(39)

def simulation_callback(arrays: da.Array, *, timestep: int):
    # Used to find the parameters of the simulation if killed before the end
    if timestep == 0:
        with open(f"{exp_dir}/results.txt", "a") as f:
            f.write(f"Starting {uuid} {len(ray.nodes()) - 1} {np.prod(arrays.numblocks)}\n")

    arrays.mean().compute(doreisa_debug_logs=f"{exp_dir}/perfs/{uuid}.txt", doreisa_partitioning_strategy="random")

    if timestep == 20:
        global start_time
        start_time = time.time()

    if timestep == 220:
        end_time = time.time()

        with open(f"{exp_dir}/results.txt", "a") as f:
            f.write(f"{uuid} {len(ray.nodes()) - 1} {np.prod(arrays.numblocks)} {1000 * (end_time - start_time) / 200}\n")

run_simulation(
    simulation_callback,
    [ArrayDefinition("arrays")],
    max_iterations=230,
)
