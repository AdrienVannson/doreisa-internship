import os
import sys
import time

import numpy as np

from doreisa.simulation_node import Client

if len(sys.argv) == 4:
    rank, total, nb_chunks_of_node = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
else:
    tasks_per_node = int(os.environ["SLURM_NTASKS_PER_NODE"])
    rank, total, nb_chunks_of_node = int(os.environ["SLURM_PROCID"]), tasks_per_node * int(os.environ["SLURM_JOB_NUM_NODES"]), tasks_per_node

with open("debug.txt", "a") as f:
    f.write(f"rank={rank} total={total} nb_chunks_of_node={nb_chunks_of_node}\n")

client = Client()
array = np.random.randint(0, 100, (10, 10), dtype=np.int64)

for _ in range(230):
    client.add_chunk("arrays", (rank,), (total,), nb_chunks_of_node, array, store_externally=False)

time.sleep(5)
