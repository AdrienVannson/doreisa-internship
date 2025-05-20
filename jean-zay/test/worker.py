import sys
import os
import socket

dir_path = os.path.dirname(os.path.realpath(__file__))
hostname = socket.gethostname()
rank = int(os.environ.get("SLURM_PROCID", "-1"))
head = sys.argv[1] if len(sys.argv) > 1 else "unknown"

with open(f"{dir_path}/output-worker-{rank}.txt", "w") as f:
    f.write(f"I'm {hostname}. I'm a worker! The head is {head}.\n")
