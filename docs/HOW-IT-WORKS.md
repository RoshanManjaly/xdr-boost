# How it works

MacBook Pros with a Liquid Retina XDR display hold normal (SDR) content to 500 nits. The panel
can reach 1,600 nits, but macOS keeps that range for HDR content. XDR Boost lets everyday
content use it.

I wanted my MacBook Pro's display above 500 nits for everyday work. I built XDR Boost in Claude
Code with the REA reverse-engineering toolkit, worked out how macOS grants HDR headroom, and
measured everything on the real panel. It uses public macOS APIs.

## The panel's numbers

The built-in display preset on the test Mac, "Apple XDR Display (P3-1600 nits)", reports:

| Preset key | Value |
|---|---|
| `PresetMaxSDRLuminance` | 500 |
| `PresetHostMaxSliderBrightness` | 500 |
| `PresetMaxHDRLuminance` | 1600 |
| `PresetHostMaxPotentialEDRHeadroom` | 16 |

The HDR Video preset on the same Mac lists the panel as "1000 nits (full-screen sustained)" with a
1,600-nit peak.

## Step 1: open the HDR headroom

A borderless 2 x 2 point window holds a `CAMetalLayer` set up for HDR:
`wantsExtendedDynamicRangeContent = true`, pixel format `rgba16Float`, color space
`extendedLinearITUR_2020`, `CAEDRMetadata.hdr10` metadata, and a fill brighter than white at 10%
opacity. While that window is on screen, macOS treats the display as showing HDR content. It raises
the backlight and grants extra headroom (`NSScreen.maximumExtendedDynamicRangeColorComponentValue`),
up to 3.2 with the brightness slider at 100%.

## Step 2: push SDR content into it

The display's gamma table (`CGGetDisplayTransferByTable` / `CGSetDisplayTransferByTable`) is
multiplied by a factor above 1.0. Values above 1.0 only show while the headroom from step 1 is open.

The table holds gamma-encoded values, so light output rises as factor ^ 2.32
([measured](MEASUREMENTS.md#1-light--factor--232)). To raise white from 500 nits to a target `top`,
XDR Boost uses:

    factor = (top / 500) ^ (1 / 2.32)

The light ratio is capped at the headroom macOS grants at that moment, so no channel clips. That
gives x1.65 for 1,600 nits and x1.42 for the 1,130-nit default. The factor ramps in by 0.02 every
0.1 s, about 2 s from off to the default.

Multiplying the table by the full headroom (x3.2) asks for about 15x the light from a panel with
3.2x of headroom, so bright colors clip and wash out toward white.

Two more details:

- Gamma tables built from a 1,024-entry read were ignored on macOS 26 (the table read back
  unchanged). Tables built from a 256-entry read work.
- Turning the boost off calls `CGDisplayRestoreColorSyncSettings` and closes the window. macOS also
  restores the gamma table when the app exits, including after a crash.
