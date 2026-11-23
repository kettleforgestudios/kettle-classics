# Kettle Classics rules

- Original work only. Kettle Forge Studios owns everything in this repo.
- One game per system, each a different genre, more complex as the system gets more complex.
- Every game exercises every button on its system's standard controller and includes a hidden **Lab mode** so it doubles as a test cartridge for Kernelcade.
- Each game is complete on its own; endings hint at the next chapter; unlock codes link them.
- Hardware-accurate, but no console-maker logos in headers (Kernelcade doesn't need them).

## Console-specific design and Kernelcade depth

- Give each chapter at least one hardware-specific showcase that serves its genre or storytelling. Choose it at the prototype stage, document the visual, sound, or gameplay payoff, and test it against the target system's timing and capacity limits. Put repeatable edge cases in Lab mode.
- Make every cartridge work as a complete flat 2D game. Keep collision, controls, rules, and essential clues independent of depth settings.
- Plan frames for Kernelcade's 2.5D presentation. Where the system allows it, keep the playable plane, actors, decorative foreground, background, and HUD distinguishable. Use depth to clarify space. Keep HUD and essential cues stable and readable.
- Keep those layer roles and conservative depth choices usable by future stereo renderers. Treat red/cyan paper-glasses anaglyph as the first stereo experiment. Test color-dependent cues in flat, left-eye, right-eye, and combined views. Keep dedicated stereoscopic glasses as a longer-term target and defer device-specific choices until that hardware and output path are defined.
- Keep Kip's chapters in story order and give each system a different genre. Put the hardware showcase where it helps that chapter, including in optional scenes or Lab when it would distract from play.

## Controller coverage and debugging

- Inventory the target controller's buttons, axes, and hardware-specific features. Give each standard button a useful role in play or menus. Exercise optional accessories, extra controller ports, and unusual combinations in Lab where they make sense for that system.
- In Lab, show input state as the controller sees it. Test each direction and button, press and release transitions, holds, simultaneous inputs, and diagonals where supported. Test alternate devices or modes only where the system supports them.
- Give every ROM a numbered, repeatable Lab test for its hardware showcase. Print the game build, test ID, and a result or short report code on-screen. Include a fixed seed or test step where useful so the same case can be replayed on original hardware or in Kernelcade.
- Record game-side counters that can reveal regressions, such as frames elapsed, input transitions, logic or render-budget overruns where measurable, and a checksum of relevant game state. Keep normal gameplay timing intact. Use a small fixed-size snapshot or ring buffer when the target has room.
- Let Kernelcade append host-side measurements in a future local export. Include emulator build, core, display mode, frame pacing, and audio underruns when available. Keep ROM-side counters distinct from host measurements. Show the report before any manual sharing. Leave out player names, device identifiers, ROM paths, and unrelated logs.
- A release test records the ROM build and checks the same Lab case in flat 2D and each supported Kernelcade depth mode. Compare against original hardware where bootable or an independent emulator. Keep pass criteria in the game's design notes.
