XDR Boost 1.0
=============

Menu-bar app that unlocks the extra brightness of a MacBook Pro XDR display
(above the normal 500-nit limit) for everyday apps, not just HDR video.

Requirements
- Apple silicon MacBook Pro with a Liquid Retina XDR display (14" or 16", 2021 or later).
- macOS 14 or later.
- Other Macs (MacBook Air, Mac mini, iMac) have no XDR headroom. The app runs there
  but shows "No XDR display on this Mac".

Install
1. Unzip XDRBoost-1.0.zip.
2. In Terminal:  bash ~/Downloads/XDRBoost/install.sh   (use the folder you unzipped to)
   It installs to ~/Applications/XDRBoost.app, clears the download quarantine flag,
   and starts the app. To install somewhere else:
   XDRBOOST_DEST=~/some/folder bash install.sh The app is not signed by Apple, so double-clicking it from a
   download may be blocked; the install script avoids that.
3. The app opens at login by default.

Menu (sun icon in the menu bar)
- Boost brightness      on / off.
- Max brightness slider 500 to 1600 nits. 1130 (default) keeps big bright areas
                        near the panel's full-screen limit, so colors stay clean.
                        1600 gives about 1600 nits on highlights. A full white screen
                        stays near 1100 nits on any setting (panel limit).
- Refresh boost         applies the slider value now and re-creates the boost.
- Open at login         on by default.
- Turns off by itself on Low Power Mode or at 20% battery or less (unplugged);
  turn it back on from the menu.

Notes
- Do not run another brightness booster at the same time. XDR Boost turns
  itself off if another app keeps resetting the display.
- Night Shift, f.lux and display calibration use the same system setting (the gamma
  table) and can conflict while the boost is on.
- Quitting the app returns the display to normal.

Uninstall
  bash uninstall.sh   (removes the login item, the app and its settings)

Source, measurements and the story: https://github.com/RoshanManjaly/xdr-boost
