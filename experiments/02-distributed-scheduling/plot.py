import matplotlib.ticker
from matplotlib import pyplot as plt

# Doreisa v0.1.5
data_1 = """1 170.16521334648132
2 185.2690351009369
4 195.1859700679779
8 219.19524550437927
16 244.32251572608948
32 311.8170154094696
64 453.9083671569824
128 928.2888233661652
255 2962.373"""  # Linear update from 254 to 255

# Doreisa v0.1.6
data_2 = """1 167.9294991493225
2 187.20595002174377
4 198.46129059791565
8 211.9185733795166
16 236.47691249847412
32 297.59584069252014
64 412.58087515830994
128 739.9024617671967
255 1429.899"""

xs, ys1, ys2 = [], [], []

for l1, l2 in zip(data_1.split("\n"), data_2.split("\n")):
    x1, y1 = map(float, l1.split(" "))
    x2, y2 = map(float, l2.split(" "))
    assert x1 == x2

    if x1 > 200:
        break

    xs.append(x1)
    ys1.append(y1)
    ys2.append(y2)

fig, ax1 = plt.subplots(1, 1, figsize=(4, 3))

# Total time per iteration
ax1.set_xlabel("Number of nodes")
ax1.set_ylabel("Time per iteration (ms)")

ax1.set_xscale("log")
# ax1.set_yscale("log")

ax1.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax1.get_xaxis().minorticks_off()
ax1.set_xticks(xs)

ax1.plot(xs, ys1)
ax1.scatter(xs, ys1)

ax1.plot(xs, ys2)
ax1.scatter(xs, ys2)

plt.tight_layout()
plt.savefig("exp-02-total-time-v0.1.5.svg")
