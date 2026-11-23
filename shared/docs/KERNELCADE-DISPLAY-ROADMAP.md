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
