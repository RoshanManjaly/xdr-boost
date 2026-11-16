# Measurements

All numbers are from the test Mac: a 16-inch MacBook Pro (2021, M1 Max) on macOS 26.7.2, with a
second MacBook facing its screen.

How I measured:

- Light: the second Mac's ambient light sensor, read in lux through `IOHIDEventSystemClient`
  ([tools/als.c](../tools/als.c)). Every white step sits between black steps, and the black
  readings are subtracted to cancel room light. I assume the sensor responds linearly. Repeat runs
  agreed within about 1%.
- Color: the second Mac's webcam, photographing a swatch pattern. Its auto-exposure and white
  balance drift between frames, so hue differences under about 10 degrees are noise.
- Test patterns: [tools/lumtest.swift](../tools/lumtest.swift) draws black, white patches of a
  chosen size, full-screen white and native HDR white, and sets the gamma factor itself.

The sensor gives ratios, not nits. To convert, I take SDR white at 100% slider as 500 nits, the
panel preset's value. Two other readings fit that: macOS grants 3.2x headroom at full brightness
(1,600 / 500), and native HDR white measured 3.24x SDR white. This is not a calibrated photometer.

## 1. Light = factor ^ 2.32

Full-screen white, slider at 64%:

| Table factor | Light gain | Exponent |
|---|---|---|
| x1.30 | 1.84x | 2.32 |
| x1.59 | 2.92x | 2.31 |
| x2.00 | 4.98x | 2.32 |
| x2.50, x3.20 | 5.8x, 5.5x | saturated |

The gamma table is gamma-encoded. A light gain `g` needs a factor of `g ^ (1 / 2.32)`: x1.65 for
the full 3.2x. Multiplying by the full headroom (x3.2) asks for about 15x.

## 2. 256-entry tables

Gamma tables built from a 1,024-entry read were ignored on this Mac: the table read back unchanged
at 1.0, whatever factor was written. Tables built from a 256-entry read apply and read back
correctly.

## 3. Peak vs full screen

Slider at 100%. "Boost" is the gamma table at x1.651. "Native HDR" is an EDR layer filled with the
current headroom, with the gamma table left alone. That is how HDR content is drawn.

| White area | Boost | Native HDR |
|---|---|---|
| 10% | ~1,120 nits | ~1,080 nits |
| 25% | 1,600-1,614 nits | 1,608-1,619 nits |
| 50% | ~1,656 nits | ~1,665 nits |
| 100% | ~1,093 nits | ~1,102 nits |

- Boost and native HDR agree within 4% at every size.
- Full-screen white stops near 1,100 nits for both and stays flat over 12 s. The limit depends on
  how much of the screen is lit, which fits a panel power limit. Neither method got past it.
- The 10% patch reads lower than 25% for both methods. I haven't worked out why.
- To rule out a sensor limit, a second full-screen run took four SDR references over 2 minutes
  (352 to 356 lux). Boost read 2.18x and 2.20x, native HDR 2.21x.

## 4. Colors

Webcam, swatch pattern, hue shift compared with the boost off:

| Setting | Saturated swatches |
|---|---|
| x3.2 (full headroom) | green -27, orange +13, purple +16 degrees. Skin tones turn cream. |
| x1.37 to x1.65 | 4 to 9 degrees, within camera noise |
