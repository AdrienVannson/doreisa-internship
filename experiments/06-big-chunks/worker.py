import sys

import numpy as np

from doreisa.simulation_node import Client

rank, total, nb_chunks_of_node = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])

client = Client()
array = np.random.randint(0, 2 ** 63, (1000, 10_000), dtype=np.int64)

for it in range(230):
    client.add_chunk("arrays", (rank, 0), (total, 1), nb_chunks_of_node, it, array)
