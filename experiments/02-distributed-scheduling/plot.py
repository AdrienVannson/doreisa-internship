import matplotlib.ticker
from matplotlib import pyplot as plt

data = """1 53.139193058013916 159.42504048347473
2 53.48182678222656 175.57791948318481
4 53.80112648010254 190.45238971710205
8 53.88177990913391 212.52898335456848
16 53.875473737716675 227.09651589393616
32 67.72971630096436 252.02704548835754
64 102.66593813896179 346.91654682159424"""

xs, ys1, ys2 = [], [], []

for line in data.split("\n"):
    x, y1, y2 = map(float, line.split(" "))

    xs.append(x)
    ys1.append(y1)
    ys2.append(y2)

# fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(8, 4))
fig, ax1 = plt.subplots(1, 1, figsize=(4, 3))

# Total time per iteration
ax1.set_xlabel("Number of nodes")
ax1.set_ylabel("Time per iteration (ms)")

ax1.set_xscale("log")
# ax1.set_yscale("log")

ax1.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax1.get_xaxis().minorticks_off()
ax1.set_xticks(xs)

ax1.plot(xs, ys2)
ax1.scatter(xs, ys2)

# Proportions
# ax2.set_xlabel("Number of chunks")
# ax2.set_ylabel("Proportion of the total time (%)")

# ax2.set_xscale("log")

# ax2.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
# ax2.get_xaxis().minorticks_off()
# ax2.set_xticks(xs)


# ratio = [y1 / y2 * 100 for y1, y2 in zip(ys1, ys2)]

# ax2.fill_between(xs, ratio, 100, alpha=0.4, facecolor="orange", label="Scheduling the tasks")
# ax2.fill_between(xs, 0, ratio, alpha=0.4, facecolor="red", label="Building the array")
# ax2.legend(loc="upper right")

# ax2.plot(xs, ratio)
# ax2.scatter(xs, ratio)

plt.tight_layout()
# plt.savefig("plot.png")
plt.savefig("plot.svg")
