import sys

file = sys.argv[1]
print("Analysing file:", file)

times: dict[str, list[float]] = {}

with open(file, 'r') as f:
    last_time = None

    for i, line in enumerate(f):
        time = 1000 * float(line.split()[0])

        # Warm up for the first 10 iterations
        if i >= 10 * 7:
            step = line.split()[1]

            if step not in times:
                times[step] = []
            times[step].append(time - last_time)

        last_time = time

s = 0

for step, time_list in times.items():
    avg_time = sum(time_list) / len(time_list)
    print(f"{step}: {avg_time:.3f} ms (n={len(time_list)})")

    s += avg_time

print(f"Total average time: {s:.3f} ms")
