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

start_time, last_time = None, None

# Unique ID for this simulation
uuid = str(random.randint(0, 2**128 - 1)).zfill(39)

def simulation_callback(arrays: list[da.Array], timestep: int):
    arr = arrays[0]

    # Used to find the parameters of the simulation if killed before the end
    if timestep == 0:
        with open(f"{exp_dir}/results.txt", "a") as f:
            f.write(f"Starting {uuid} {len(ray.nodes()) - 1} {np.prod(arr.numblocks)}\n")

    dsk = arr.mean()
    dsk.compute(doreisa_debug_logs=f"{exp_dir}/perfs/{uuid}.txt")  # Add optimize_graph=False if useful

    global last_time

    current_time = time.time()
    if last_time is not None:
        with open(f"{exp_dir}/timesteps/{uuid}.txt", "a") as f:
            f.write(f"{timestep} {current_time - last_time}\n")
    last_time = time.time()

    if timestep in [20, 800]:
        global start_time
        start_time = time.time()

    if timestep in [220, 1000]:
        end_time = time.time()

        with open(f"{exp_dir}/results.txt", "a") as f:
            f.write(f"{uuid} {len(ray.nodes()) - 1} {np.prod(arr.numblocks)} long_warmup={timestep==1000} {1000 * (end_time - start_time) / 200}\n")


run_simulation(
    simulation_callback,
    [ArrayDefinition("arrays", window_size=1)],
    max_iterations=230,
)
