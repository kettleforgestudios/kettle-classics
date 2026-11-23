# Kernelcade display roadmap

## Flip-style foldables

- Use the Motorola Razr (2025) for the first pass. Exercise fold, unfold, half-open tabletop posture, rotation, and cover-to-inner display transitions where allowed by the device. Preserve the running game, aspect ratio, controller mapping, and touch layout. If the game becomes hidden, pause cleanly and restore it on return. Check audio and stuck inputs at each transition.
- Prototype tabletop play with the game above the hinge and touch controls below. Explore optional cover-screen quick play, starting with Kernel Drop and checking readability and control comfort.
- Validate on a second flip-style model before claiming broader foldable compatibility.

## Book-style foldables

- Keep in exploration. Compare cover-to-inner continuity, hinge-safe layouts, a larger game view with a physical controller, and touch controls that fit the opened display. Validate on physical book-style hardware before treating it as covered.

## Two physical displays

- Use the owner's second-screen attachment on both the Retroid Pocket Nova and Retroid Pocket 6. Check whether Android exposes it as an independent display on each setup. Test attach, detach, reconnect, screen switching during gameplay, focus, touch routing, and built-in controller input. Fall back to the remaining screen without restarting the game.
- For single-screen systems, let the player toggle which display shows the game mid-session. Offer optional roles for the other display, including extra touch buttons, emulator shortcuts, in-game information where available, or blank.
- If DS or 3DS emulation is added, show the emulated top and bottom screens on their corresponding physical displays, with touch routed to the emulated bottom screen where supported. Provide a combined layout when there is one display. Keep this display routing separate from stereoscopic rendering.

The existing 20-device compatibility list and the Beta gate for external testing still apply.

## Android layout settings and validation

- Add a Display & Layout settings section with Auto as the default, a preview and reset, and per-posture overrides for game placement, touch-control placement and visibility, aspect ratio, and secondary-screen role where available. Expose only options the current device and window can use.
- Cover compact through extra-large windows, portrait and landscape, flat and half-open/tabletop and book postures, cover and inner displays, tablets, split-screen, resizable/freeform windows including desktop windowing, and external or secondary displays where Android exposes them. Keep picture-in-picture and multiple app instances as exploration items with explicit audio, input, and session behavior to resolve.
- Use available window space and hinge/inset information to avoid obscured content. Preserve the game session across posture, rotation, resize, and display changes. Clear held inputs on focus loss and check audio, overlays, and navigation with touch and controller.
- Apply the relevant layout checks across the existing 20 device targets. Use the Razr for flip/tabletop and the Nova and Pocket 6 attachments for independent-display checks. Add physical book-style validation when hardware is available.

## Controller compatibility targets

**Available for in-house testing:** PS4 DualShock 4, Xbox Series Wireless Controller, and 8BitDo Ultimate 2 Wireless Controller (WUCHANG: Fallen Feathers Edition).

These are provisional coverage picks. Reorder when reliable Android-specific usage data is available. Both peripheral lists are in addition to the 20 Android devices.

| Slot | Standalone gamepad | Phone-mounted controller |
|---|---|---|
| 1 | Xbox Wireless Controller (Series X/S) | Backbone One USB-C (2nd Gen) |
| 2 | Xbox Wireless Controller (Bluetooth Xbox One revision) | Backbone Pro |
| 3 | Sony DualSense | GameSir G8 Galileo |
| 4 | Sony DualShock 4 | GameSir G8 Plus |
| 5 | Nintendo Switch Pro Controller | GameSir X2s USB-C |
| 6 | Nintendo Joy-Con (left and right) | GameSir X4 Aileron |
| 7 | 8BitDo Ultimate 2C Bluetooth | Razer Kishi V3 |
| 8 | 8BitDo Pro 2 Bluetooth | Razer Kishi V3 Ultra |
| 9 | 8BitDo SN30 Pro Bluetooth | Razer Kishi V2 USB-C |
| 10 | SteelSeries Stratus+ | abxylute S9 |

- Check all buttons and axes supported by each controller, including D-pad diagonals, triggers, sticks and stick clicks, menu controls, simultaneous inputs, and rumble where available. Record connection mode and controller revision. Test reconnect, pause/resume, touch-to-gamepad handoff, and layout switching during play.
- For phone mounts, record physical fit separately from input compatibility. Check USB-C alignment and clearance, cases and camera bumps, foldable fit, and passthrough charging when supported.
- Test representative device/controller combinations across Android versions and form factors, then expand around failures. Keep built-in handheld controls in the device checks.
