# XDR Boost

A small macOS menu-bar app that unlocks the extra brightness of a MacBook Pro's Liquid Retina XDR
display: everyday (SDR) content above the normal 500-nit limit, up to about 1,600 nits on
highlights.

- One toggle in the menu bar, a 500 to 1,600 nit slider, and a Refresh button.
- The default, 1,130, keeps large bright areas near the panel's full-screen ceiling, so colors stay
  clean.
- Keeps macOS auto-brightness working: the boost scales whatever the system slider is doing.
- Turns itself off on Low Power Mode or at 20% battery or less, and you can turn it back on.
- Opens at login (toggle in the menu). Quitting returns the display to normal.
- About 400 lines of Swift, public macOS APIs only, MIT licensed.

## Requirements

- Apple silicon MacBook Pro with a Liquid Retina XDR display (14-inch or 16-inch, 2021 or later).
- macOS 14 or later.

Other Macs (MacBook Air, Mac mini, iMac) have no XDR headroom. The app runs there but shows
"No XDR display on this Mac".

## Install

1. Download `XDRBoost-1.0.zip` from [Releases](https://github.com/RoshanManjaly/xdr-boost/releases)
   and unzip it.
2. In Terminal:

   ```bash
   bash ~/Downloads/XDRBoost/install.sh
   ```

   It installs to `~/Applications/XDRBoost.app` (set `XDRBOOST_DEST` to choose another folder),
   removes the download quarantine flag and starts the app.

The app is ad-hoc signed, not notarized by Apple, so double-clicking a downloaded copy may be
blocked by Gatekeeper. The install script avoids that. If you prefer, build it yourself (below).

## Use

Click the sun icon in the menu bar. If you use a menu bar manager such as Bartender, the icon may
start in its hidden section.

| Menu item | What it does |
|---|---|
| Boost brightness | Turns the boost on or off (the icon fills in when on). |
| Max brightness slider | 500 to 1,600 nits. **1130 (default)** keeps colors clean. **1600** gives the full ~1,600-nit highlights. |
| Refresh boost | Applies the slider value now and re-creates the boost (also fixes a boost lost after sleep). |
| Open at login | On by default. |

A full white screen stays near 1,100 nits at any setting. That is the panel's own limit (see
below), not the app's.

## How it works

Two steps:

1. A tiny 2 x 2 point HDR window makes macOS treat the screen as showing HDR content, so it raises
   the backlight and opens up to 3.2x of headroom.
2. The display's gamma table is multiplied by a factor above 1.0 so normal content uses that
   headroom. The table is gamma-encoded, so light = factor ^ 2.32. The app picks
   `factor = (top / 500) ^ (1 / 2.32)`, never more than the headroom allows, and ramps in over
   about a second so colors do not flash.

Details: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## Measured results

Measured on the test Mac with a second MacBook's ambient light sensor as a light meter
([methodology and all data](docs/MEASUREMENTS.md)):

| | 25% of the screen white | Full screen white |
|---|---|---|
| Boost off (slider 100%) | 500 nits | 500 nits |
| XDR Boost at 1130 (default) | ~1,081 nits | ~1,061 nits |
| XDR Boost at 1600 | ~1,600 nits | ~1,093 nits |
| Native HDR video white | ~1,610 nits | ~1,102 nits |

## How it came to be

I wanted my MacBook Pro's display above 500 nits for everyday work, toward the panel's 1,600-nit
peak, in a tiny menu-bar app.

The work was done in Claude Code with the REA reverse-engineering toolkit: working out how macOS
grants HDR headroom, and then testing on the real panel. The first version scaled the gamma table
by the full headroom (x3.2) and washed out colors. Getting it right took measurement: a
second MacBook sat facing the screen, its ambient light sensor used as a light meter and its webcam
used to photograph color swatches. That showed:

- The gamma table is gamma-encoded (light = factor ^ 2.32), so x3.2 asked for about 15x the light
  and clipped every bright color.
- Writes built from a 1,024-entry gamma table were silently ignored; 256 entries work.
- A full white screen tops out near 1,100 nits for any method, including native HDR video.
  1,600 nits is a highlight peak.
- A factor of x1.42 (1,130 nits) keeps large bright areas near that full-screen limit instead of
  past it, so colors stay clean. XDR Boost now defaults to that level.

The commit history follows those iterations, from the first prototype to v1.0.

## Tested on

| | |
|---|---|
| Mac | MacBook Pro 16-inch (2021), Apple M1 Max (MacBookPro18,2) |
| Display | Built-in Liquid Retina XDR, preset "Apple XDR Display (P3-1600 nits)" |
| macOS | 26.7.2 (25G332) |
| Measurement rig | a second MacBook's ambient light sensor and webcam facing the screen |

Other XDR MacBook Pros share the 1,600-nit peak panel and should behave the same. Newer models
with a higher SDR maximum may land at slightly different nits. Reports are welcome.

## Caveats

- Do not run another brightness booster at the same time. Both write the gamma table. XDR Boost
  turns itself off if another app keeps resetting it.
- Night Shift, f.lux and display calibration also use the gamma table and can conflict.
- HDR video highlights are compressed while the boost is on.
- More brightness means more power use and heat.

## Build from source

Needs the Xcode command line tools (`xcode-select --install`).

```bash
./build.sh              # builds build/XDRBoost.app and installs it to ~/Applications
./build.sh --no-install # build only
./package.sh            # builds build/XDRBoost-<version>.zip with install and uninstall scripts
```

Measurement tools are in [tools/](tools/).

## Uninstall

```bash
bash uninstall.sh   # from the release zip: removes the login item, the app and its settings
```

## Credits

- [BrightIntosh](https://github.com/niklasr22/BrightIntosh) by Niklas Rousset, a useful reference for
  the HDR trigger technique and its brightness factors. No BrightIntosh code is included.

## License

MIT. See [LICENSE](LICENSE).
