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

## Ranked compatibility targets

Each list is ordered by estimated commonness for a U.S.-focused Android test program. Exact positions are approximate because public usage data is limited.

New-unit U.S. budget references checked November 23, 2026, in USD before tax, shipping, or import duty. Retail and sale figures are snapshots. MSRP, historical prices, and estimates are listed where a live new-unit offer is unclear. Check the exact variant and stock before buying.

Price references include [Retroid](https://www.goretroid.com/collections/retro-game-system), [AYN](https://www.ayntec.com/collections/odin), [Google Store](https://store.google.com/us/config/pixel_10_pro), [Sony](https://direct.playstation.com/en-us/deals/black-friday-accessories), [Nintendo](https://www.nintendo.com/us/store/hardware/), [8BitDo](https://shop.8bitdo.com/collections/shop-8bitdo-com-exclusive), [Backbone](https://backbone.com/), [GameSir](https://gamesir.com/compare?compareSource=recommended&products=gamesir-g8-galileo%2Cg8plus-bluetooth-mobile-controller), and [Razer](https://www.razer.com/newsroom/product-news/razer-unleashes-the-new-kishi-v3-lineup).

### Devices

1. Samsung Galaxy S25 Ultra — $1,299.99 MSRP (256 GB, unlocked)
2. Samsung Galaxy A16 5G — $199.99 MSRP (unlocked)
3. Motorola Moto G (2025) — $169.99 Motorola listing ($199.99 regular, unlocked)
4. Samsung Galaxy Tab A9+ — $219.99 MSRP (64 GB Wi-Fi)
5. Google Pixel 10 Pro — $999 Google Store (128 GB, unlocked)
6. Motorola Razr (2025) — $699.99 launch MSRP (unlocked)
7. OnePlus 13 — $899 launch price (256 GB, unlocked)
8. Xiaomi Redmi Note 14 5G — $379 historical U.S. program price (program ended, check new import stock)
9. Nothing Phone (3a) — $199.97 new marketplace listing (global unlocked import)
10. ASUS ROG Phone 9 — $999.99 launch MSRP (base model, check new stock)
11. Retroid Pocket 5 — $179 manufacturer listing (check stock)
12. Retroid Pocket 6 — $244 manufacturer listing (check stock)
13. AYN Thor — From $259 manufacturer preorder
14. AYN Odin 2 Portal — From $259 manufacturer listing ($329 regular, check stock)
15. Retroid Pocket Flip 2 — From $149 manufacturer listing (check stock)
16. Retroid Pocket Classic — $99 manufacturer listing (check stock)
17. MANGMI Air X — $99.99 manufacturer listing
18. Anbernic RG 477M — $264.99 tracked new price (check seller and stock)
19. Retroid Pocket Nova — $239 manufacturer listing (check stock)
20. AYANEO Pocket DMG — About $419–$560 listed new, depending on configuration

### Controllers

1. Xbox Wireless Controller (Series X/S) — About $49–$65 regular retail, depending on color
2. Sony DualShock 4 — $64.99 GameStop new listing (check stock)
3. Sony DualSense — $54 Sony sale listing (white or midnight black, check sale availability)
4. Xbox Wireless Controller (Xbox One Bluetooth revision) — About $60 historical retail benchmark (exact model 1708, sealed stock and current price vary)
5. Nintendo Switch Pro Controller — $79.99 Nintendo regular price
6. Nintendo Joy-Con (left and right) — $89.99 Nintendo regular price (pair)
7. 8BitDo Ultimate 2C Bluetooth — $29.99 manufacturer listing (Switch Bluetooth model, verify Android behavior)
8. 8BitDo Pro 2 Bluetooth — $44.99 manufacturer special-edition listing
9. 8BitDo SN30 Pro Bluetooth — $39.99 manufacturer special-edition listing
10. SteelSeries Stratus+ — About $48–$60 listed new (check stock)

### Phone-mounted controllers

1. Backbone One USB-C (2nd Gen) — $79.99 regular ($59.99 Backbone sale)
2. GameSir G8 Galileo — $59.99 manufacturer listing
3. GameSir G8 Plus — $79.99 manufacturer listing
4. Razer Kishi V2 USB-C — $99.99 Verizon listing (check stock)
5. GameSir X2s USB-C — About $46 new (budget estimate, USB-C version)
6. Backbone Pro — $169.99 regular ($119.99 Backbone sale)
7. Razer Kishi V3 — $99.99 MSRP
8. Razer Kishi V3 Pro — $149.99 launch MSRP
9. GameSir X4 Aileron — About $100 new (budget estimate)
10. abxylute S9 — About $70–$90 new (budget estimate)

- Check all buttons and axes supported by each controller, including D-pad diagonals, triggers, sticks and stick clicks, menu controls, simultaneous inputs, and rumble where available. Record connection mode and controller revision. Test reconnect, pause/resume, touch-to-gamepad handoff, and layout switching during play.
- For phone mounts, record physical fit separately from input compatibility. Check USB-C alignment and clearance, cases and camera bumps, foldable fit, and passthrough charging when supported.
- Test representative device/controller combinations across Android versions and form factors, then expand around failures. Keep built-in handheld controls in the device checks.
