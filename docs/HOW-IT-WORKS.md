# How the XDR brightness unlock works

MacBook Pros with a Liquid Retina XDR display cap normal (SDR) content at 500 nits, while the
panel can reach 1,600 nits for HDR highlights. XDR Boost lets you push everyday content into that
extra range.

I wanted my MacBook Pro's display above 500 nits for everyday work. I built XDR Boost in Claude
Code with the REA reverse-engineering toolkit, worked out how macOS grants HDR headroom, and
measured everything on the real panel. These notes describe how it works.

## The panel's own numbers

The built-in display preset "Apple XDR Display (P3-1600 nits)" on the test Mac reports:

| Preset key | Value |
|---|---|
| `PresetMaxSDRLuminance` | 500 |
| `PresetHostMaxSliderBrightness` | 500 |
| `PresetMaxHDRLuminance` | 1600 |
| `PresetHostMaxPotentialEDRHeadroom` | 16 |

The HDR Video preset on the same Mac describes the panel as "1000 nits (full-screen sustained)"
and 1600 nits peak. That distinction matters later.

## XDR Brightness (public APIs)

Two steps:

1. **Open the HDR headroom.** A borderless 2 x 2 point window holds a `CAMetalLayer` with
   `wantsExtendedDynamicRangeContent = true`, pixel format `rgba16Float`, color space
   `extendedLinearITUR_2020`, `CAEDRMetadata.hdr10` metadata, and a fill brighter than white
   (the panel's potential headroom), at 10% opacity. Its presence tells macOS that HDR content is on
   screen, so the system raises the backlight and reports extra headroom
   (`NSScreen.maximumExtendedDynamicRangeColorComponentValue`, 3.2 at full slider brightness).
2. **Push SDR content into it.** The display's gamma table
   (`CGGetDisplayTransferByTable` / `CGSetDisplayTransferByTable`) is multiplied by a factor above
   1.0. Values above 1.0 only take effect while the headroom from step 1 is open.

Turning it off restores the gamma table (`CGDisplayRestoreColorSyncSettings`) and closes the
window. If the app crashes, macOS resets the gamma table when the process exits.

## The open question: how big a factor?

My first version multiplied the table by the full headroom (x3.2 at full brightness). On the test
panel that washed out colors: bright, saturated colors drifted toward white. Finding out why, and
what factor looks right, took measurement. See [MEASUREMENTS.md](MEASUREMENTS.md).

## Limits that apply to any approach

- 1,600 nits is a highlight peak. A full white screen stays near 1,000 to 1,100 nits.
- Night Shift, f.lux and display calibration also own the gamma table and conflict with the boost.
- HDR video highlights are compressed while the boost is on.
- Only the built-in XDR panel is supported.
