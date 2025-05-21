import sys
import time

import numpy as np

from doreisa.simulation_node import Client

rank, total = int(sys.argv[1]), int(sys.argv[2])

client = Client(rank)
array = np.random.randint(0, 100, (10, 10), dtype=np.int64)

for _ in range(125):
    client.add_chunk("arrays", (rank,), (total,), array, store_externally=False)

time.sleep(10)
