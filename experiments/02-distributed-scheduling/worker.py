import sys
import time

import numpy as np

from doreisa.simulation_node import Client

rank, total, nb_chunks_of_node = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])

client = Client()
array = np.random.randint(0, 100, (10, 10), dtype=np.int64)

for _ in range(230):
    client.add_chunk("arrays", (rank,), (total,), nb_chunks_of_node, array, store_externally=False)

time.sleep(5)
