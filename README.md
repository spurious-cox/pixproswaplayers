# PixProSwapLayers 3.2.0

Exchanges the stacking order of the selected Pixelmator Pro layers. The first
selected layer trades places with the last, the second with the second to last,
and so on; two layers simply swap. An odd layer in the middle has no partner
and stays where it is.

### [⬇︎ Download the latest release](https://github.com/spurious-cox/pixproswaplayers/releases/latest)

Notarized and stapled by Apple — open the DMG and drag PixProSwapLayers to
Applications, or install it with Homebrew:

```
brew install --cask spurious-cox/tap/pixproswaplayers
```

Requires Pixelmator Pro and macOS 26 or later. Both the 3.x build and the
Creator Studio build work; the app binds to whichever one is in front or has a
document open.

## Using it

Select two or more layers in Pixelmator Pro and run it. Nothing to answer — it
swaps and gets out of the way.

Layers inside groups are handled: each keeps to its own parent's ordering,
which is what the layer index counts in.

Run it with fewer than two selected and it says so — "Select two or more
layers in Pixelmator Pro, then run PixProSwapLayers again" — and quits.

It deliberately does not wait while you select. A dialog of its own takes the
focus the moment it appears, so the layers cannot be clicked; a notification
instead is silent if notifications are switched off; and an app left waiting
swallows the next launch, because macOS will not start a second copy. Finishing
immediately is the only behavior that is always visible.

## One version number

The app, the script inside it, the dialogs, the release and the Homebrew cask
all read **3.2.0**. `build.sh` takes that number from `property scriptVersion`
in the source rather than keeping its own copy, so the bundle cannot claim a
version the code does not.

## Building

```
./build.sh
```

Compiles the script, installs the icon, restores the bundle identity that
`osacompile` drops, stamps the applet's minimum macOS back to 26, signs with
Developer ID and installs to `/Applications`.

The icon is built from the master artwork with `pixpro_icon SwapLayers`.

## Problems or suggestions

Open an issue: https://github.com/spurious-cox/pixproswaplayers/issues

## License

MIT. See LICENSE.
