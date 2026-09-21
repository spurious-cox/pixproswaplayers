# PixProSwapLayers

Exchanges the stacking order of the selected Pixelmator Pro layers. The first
selected layer trades places with the last, the second with the second to last,
and so on; two layers simply swap. An odd layer in the middle has no partner
and stays where it is.

## Using it

Select two or more layers in Pixelmator Pro and run it. Nothing to answer — it
swaps and gets out of the way.

Run it with fewer than two selected and it waits instead of refusing:
Pixelmator comes to the front, a notification says what it is waiting for, and
the swap happens as soon as two layers are selected. It gives up after a
minute. There is deliberately no dialog while it waits — a dialog belonging to
this app takes the focus the moment it appears, and the layers could not be
clicked.

Layers in different groups are handled: each one keeps to its own parent's
ordering, which is what `index` counts in.

## What changed in 2.0.0

Version 1.3 was an Automator application wrapping a Run AppleScript action.
Three things came with that:

- It opened with `tell application "Pixelmator Pro"`, a name resolved when the
  workflow was saved. Since the Creator Studio rebrand that name can be the
  wrong copy, or one with no document open. It now finds the running
  Pixelmator by bundle id, preferring the frontmost and then any with a
  document open — so both the 3.x build and Creator Studio work.
- Its debugging switch was left on, so it stopped at four dialogs on the way
  through a swap.
- The Automator stub was unsigned and carried Apple's identifier with the
  app's own name misspelled inside it. Gatekeeper rejected it. It is now a
  signed applet with its own identifier.

The swapping itself is unchanged.

## Building

```
./build.sh
```

Compiles the script, installs the icon, restores the bundle identity that
`osacompile` drops, stamps the applet's minimum macOS back to 26, signs with
Developer ID and installs to `/Applications`. The version comes from
`property scriptVersion` in the source.

The icon is built from the master artwork with `pixpro_icon SwapLayers`.
