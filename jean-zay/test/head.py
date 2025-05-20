import os
import socket

dir_path = os.path.dirname(os.path.realpath(__file__))
hostname = socket.gethostname()

with open(f"{dir_path}/output-head.txt", "w") as f:
    f.write(f"I'm {hostname}. I'm the head!\n")
