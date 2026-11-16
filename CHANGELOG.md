# Changelog

## 1.0.1 (2026-11-15)

- App icon.
- One-line installer:
  `curl -fsSL https://raw.githubusercontent.com/RoshanManjaly/xdr-boost/main/install.sh | bash`
- The release asset is now `XDRBoost.zip`, without a version number, so
  `releases/latest/download/XDRBoost.zip` always gets the newest build.
- Fixed a run-on line in the bundled README.txt.

The boost itself is unchanged.

## 1.0.0 (2026-11-15)

First release.

- Menu-bar switch that opens the panel's HDR headroom and scales the gamma table so normal content
  uses it.
- Slider from 500 to 1,600 nits. The default, 1,130, applies a factor of x1.42.
- Ramps in over about 2 s at the default.
- Turns itself off in Low Power Mode, at 20% battery or less while unplugged, or when another app
  keeps resetting the gamma table.
- Refresh boost, open at login, and install and uninstall scripts.
