import matplotlib.ticker
from matplotlib import pyplot as plt

data = """1 21.683921813964844 59.4044303894043
2 42.2997522354126 114.3592357635498
4 85.89776039123535 223.9240312576294
8 178.43984127044678 440.4931426048279
16 358.98892879486084 893.9356851577759
32 751.2908339500427 1841.4704251289368"""

xs, ys1, ys2 = [], [], []

for line in data.split("\n"):
    x, y1, y2 = map(float, line.split(" "))

    xs.append(x)
    ys1.append(y1)
    ys2.append(y2)

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(6, 3))

# Total time per iteration
ax1.set_xlabel("Number of simulation nodes")
ax1.set_ylabel("Time per iteration (ms)")

ax1.set_xscale("log")
ax1.set_yscale("log")

ax1.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax1.get_xaxis().minorticks_off()
ax1.set_xticks(xs)

ax1.plot(xs, ys2)
ax1.scatter(xs, ys2)

# Proportions
ax2.set_xlabel("Number of simulation nodes")
ax2.set_ylabel("Proportion of the total time (%)")

ax2.set_xscale("log")

ax2.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax2.get_xaxis().minorticks_off()
ax2.set_xticks(xs)


ratio = [y1 / y2 * 100 for y1, y2 in zip(ys1, ys2)]

ax2.fill_between(xs, ratio, 100, alpha=0.4, facecolor="orange", label="Scheduling the tasks")
ax2.fill_between(xs, 0, ratio, alpha=0.4, facecolor="red", label="Building the array")
ax2.legend(loc="upper right")

ax2.plot(xs, ratio)
ax2.scatter(xs, ratio)

plt.tight_layout()
plt.savefig("plot.svg")
