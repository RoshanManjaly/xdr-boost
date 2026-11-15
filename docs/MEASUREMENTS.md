# Measurements

All numbers come from the test Mac (16-inch MacBook Pro, M1 Max, macOS 26.7.2) with a second
MacBook facing its screen:

- **Light meter:** the second Mac's ambient light sensor, read in lux through
  `IOHIDEventSystemClient` ([tools/als.c](../tools/als.c)). It responds linearly, so it measures
  ratios exactly. Each white step is compared with black steps on both sides to cancel room light.
- **Color:** the second Mac's webcam photographing a swatch pattern. Its auto-exposure and white
  balance move between frames, so hue differences under about 10 degrees are noise.
- **Test patterns:** [tools/lumtest.swift](../tools/lumtest.swift) draws black, white patches,
  full-screen white and native HDR white, and can set the gamma factor itself.

Absolute nits assume SDR white = 500 nits at 100% slider. Three sources agree on that anchor:
the panel preset (500), macOS's headroom at full brightness (3.2 = 1600 / 500), and native HDR
white measuring 3.24x SDR white.

## 1. The gamma table is gamma-encoded

Full-screen white, slider at 64%:

| Table factor | Light gain | Exponent |
|---|---|---|
| x1.30 | 1.84x | 2.32 |
| x1.59 | 2.92x | 2.31 |
| x2.00 | 4.98x | 2.32 |
| x2.50 / x3.20 | 5.8x / 5.5x | saturated |

So light = factor ^ 2.32. Multiplying by the full headroom (x3.2) asks for about 15x the light
while the panel has 3.2x of headroom at full brightness. Every bright channel clips, which is the
washed-out look. The right factor for a light gain `g` is `g ^ (1 / 2.32)`: x1.65 for the full
3.2x.

Writes built from a 1024-entry table read were silently ignored on this Mac. 256 entries work.

## 2. Peak vs full screen

Slider at 100%. "Boost" is the gamma table at x1.651; "native HDR" is an EDR layer filled with the
current headroom, with the gamma table untouched (what an HDR video does).

| White area | Boost | Native HDR |
|---|---|---|
| 10% | ~1,120 nits | ~1,080 nits |
| 25% | ~1,600 to 1,614 nits | ~1,608 to 1,619 nits |
| 50% | ~1,656 nits | ~1,665 nits |
| 100% | ~1,093 nits | ~1,102 nits |

- The boost matches native HDR within 4% at every area.
- A full white screen stops near 1,100 nits for both, and it stays flat over 12 s. The limit
  depends on lit area, which is what a panel power limit looks like. No app gets past it.
- A repeated-reference run (four SDR references, 352 to 356 lux over 2 minutes, sensor well inside
  its range) gave boost 2.18x and 2.20x, native HDR 2.21x.

## 3. Colors

Webcam, swatch pattern, hue shift vs boost off:

| Setting | Saturated swatches |
|---|---|
| x3.2 (full headroom) | green -27, orange +13, purple +16 degrees; skin tones turn cream |
| x1.37 to x1.65 | within about 4 to 9 degrees (inside the camera's noise) |
