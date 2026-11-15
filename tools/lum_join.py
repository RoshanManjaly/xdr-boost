"""Join lumtest step log with ALS lux samples; report screen contribution per white step.

For each step, use the median lux of the last 60% of the hold (lets the sensor settle).
White contribution = white lux - mean of the neighbouring black steps.
"""
import statistics
import sys

out, hold = sys.argv[1], float(sys.argv[2])
als = []
for line in open(f"{out}/als.txt"):
    p = line.split()
    if len(p) == 2 and p[1] != "nan":
        als.append((int(p[0]), float(p[1])))
steps = []
for line in open(f"{out}/steps.txt"):
    p = line.split()
    if len(p) >= 4 and p[1].isdigit():
        steps.append((int(p[0]), int(p[1]), p[2], float(p[3]) if p[3].replace(".", "").isdigit() else 1.0, " ".join(p[4:])))

def level(t0):
    a, b = t0 + int(hold * 400), t0 + int(hold * 1000) - 100
    vals = [v for t, v in als if a <= t <= b]
    return statistics.median(vals) if vals else float("nan"), len(vals)

rows = [(s, *level(s[0])) for s in steps]
blacks = {s[1]: lv for s, lv, _ in rows if s[2] == "b"}
print(f"{'step':>4} {'kind':>4} {'factor':>6} {'lux':>8} {'n':>3}  {'screen lux':>10} {'gain':>6}  info")
ref = None
for s, lv, n in rows:
    i, kind, f = s[1], s[2], s[3]
    if kind == "s":
        continue
    if kind == "b":
        print(f"{i:>4} {kind:>4} {f:>6.2f} {lv:>8.1f} {n:>3}")
        continue
    nb = [blacks[j] for j in (i - 1, i + 1) if j in blacks]
    contrib = lv - statistics.mean(nb) if nb else float("nan")
    if f == 1.0 and kind == "w" and ref is None:
        ref = contrib
    gain = contrib / ref if ref else float("nan")
    if kind == "p":
        gain = contrib / (ref / 4) if ref else float("nan")  # patch is 25% of the area
    print(f"{i:>4} {kind:>4} {f:>6.2f} {lv:>8.1f} {n:>3}  {contrib:>10.1f} {gain:>6.2f}  {s[4]}")
