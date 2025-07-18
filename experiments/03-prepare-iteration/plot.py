import matplotlib.ticker
from matplotlib import pyplot as plt

xs = [1, 2, 4, 8, 16, 32, 64, 128]

ys = {
    1: [111.03088855743408, 133.55244517326355, 98.15911173820496, 108.64637732505798, 120.7501757144928, 154.50950145721436, 230.31348943710327, 404.80636835098267],
    2: [71.82352781295776, 73.24533104896545, 76.66063189506531, 81.26147270202637, 94.63837623596191, 127.50747084617615, 163.56025099754333, 282.74632573127747],
    8: [75.13591885566711, 77.50453114509583, 78.40057969093323, 86.59335136413574, 95.01416683197021, 112.60998487472534, 148.00142645835876, 219.2269241809845],
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

for k, v in ys.items():
    ax.plot(xs[:len(v)], v, label=f"{k} iterations")
    ax.scatter(xs[:len(v)], v)

ax.legend()

plt.tight_layout()
plt.savefig("plot.svg")
