import matplotlib.ticker
from matplotlib import pyplot as plt

xs = [1, 2, 4, 8, 16, 32, 64, 128]

ys = {
    "Random partitioning": [139.71401929855347, 213.86755347251892, 353.8294267654419, 401.19176864624023, 552.5259923934937, 797.037615776062, 932.1616971492767],
    "Greedy partitioning": [142.64453530311584, 165.57361841201782, 177.8764009475708, 197.60260701179504, 218.06633114814758, 267.5287115573883, 386.14498257637024],
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
