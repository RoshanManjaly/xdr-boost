# Measurement tools

These are the tools used to measure the panel (see [docs/MEASUREMENTS.md](../docs/MEASUREMENTS.md)).
They need two Macs: the one under test, and a second Mac whose ambient light sensor (next to its
camera) faces the first one's screen.

| Tool | Runs on | What it does |
|---|---|---|
| `als.c` | second Mac | Prints `epoch_ms lux` from the ambient light sensor (private `IOHIDEventSystemClient` API). |
| `lumtest.swift` | Mac under test | Steps through black, white patches, full-screen white and native HDR white with optional gamma factors. Logs `epoch_ms step kind ...` per step. Uses the private DisplayServices API to set the brightness slider. |
| `lum_join.py` | either | Joins the two logs by timestamp and prints each step's screen contribution (lux minus neighbouring black steps). |

## Build

```bash
clang -O2 -o als tools/als.c -framework IOKit -framework CoreFoundation   # second Mac
swiftc -O -o lumtest tools/lumtest.swift                                   # Mac under test
```

## Run

Keep both clocks in sync (NTP, the default). Start the sensor first, then the steps:

```bash
# second Mac: 1,500 samples, 100 ms apart
./als 1500 100 > als.txt

# Mac under test: 8 s per step
./lumtest 8 s:1.0 b q:1:0.25 b q:1.651:0.25 b h:0.25 b q:1:1.0 b q:1.651:1.0 b h:1.0 b > steps.txt

# put als.txt and steps.txt in one folder, then:
python3 tools/lum_join.py <folder> 8
```

Step specs:

| Spec | Meaning |
|---|---|
| `s:<v>` | set the brightness slider to `v` (0 to 1); restored at the end |
| `b` | full-screen black |
| `w:<f>` | full-screen white, gamma factor `f` |
| `p:<f>` | 25% white patch, gamma factor `f` |
| `q:<f>:<area>` | white patch of the given area fraction, gamma factor `f` |
| `h:<area>` | native HDR white patch (EDR layer at the current headroom), gamma untouched |

Set `NOGAMMA=1` to leave the gamma table alone, for example to measure another app's boost.

Pitfalls found along the way:

- Schedule each step from the previous one. Timers set far ahead get coalesced by the system and fire
  in pairs.
- Take repeated references. A single reference right after a brightness change can read low.
