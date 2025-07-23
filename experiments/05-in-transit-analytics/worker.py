import sys

import numpy as np

from doreisa.simulation_node import InTransitClient

rank, total, nb_chunks_of_node = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])

print("Starting worker with parameters:", sys.argv[1:])

client = InTransitClient(analytic_node_address=sys.argv[4])
array = np.random.randint(0, 100, (10, 10), dtype=np.int64)

for it in range(230):
    client.add_chunk("arrays", (rank,), (total,), nb_chunks_of_node, it, array)
