import matplotlib.ticker
from matplotlib import pyplot as plt

xs = [1, 2, 4, 8, 16, 32, 64, 128]

ys = {
    "Centralized scheduling": [59.4044303894043, 114.3592357635498, 223.9240312576294, 440.4931426048279, 893.9356851577759],  # 1841.4704251289368
    "Distributed scheduling": [167.9294991493225, 187.20595002174377, 198.46129059791565, 211.9185733795166, 236.47691249847412, 297.59584069252014, 412.58087515830994, 739.9024617671967],
}

fig, ax = plt.subplots(1, 1, figsize=(6, 3))

# Total time per iteration
ax.set_xlabel("Number of simulation nodes")
ax.set_ylabel("Time per iteration (ms)")

ax.set_xscale("log")
# ax.set_yscale("log")

ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax.get_xaxis().minorticks_off()
ax.set_xticks(xs)

for name, v in ys.items():
    ax.plot(xs[:len(v)], v, label=name)
    ax.scatter(xs[:len(v)], v)

ax.legend()

plt.tight_layout()
plt.savefig("plot.svg")
