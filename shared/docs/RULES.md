# Kettle Classics rules

- Original work only. Kettle Forge Studios owns everything in this repo.
- One game per system, each a different genre, more complex as the system gets more complex.
- Every game uses EVERY button on its system and has a hidden **Lab mode** (button test,
  sound channel test, graphics layer tests) so it doubles as a test suite for Kernelcade.
- Each game is complete on its own; endings hint at the next chapter; unlock codes link them.
- Hardware-accurate, but no console-maker logos in headers (Kernelcade doesn't need them).

## Console-specific design and Kernelcade depth

- Give each chapter at least one hardware-specific showcase that serves its genre or storytelling. Choose it at the prototype stage, document the visual, sound, or gameplay payoff, and test it against the target system's timing and capacity limits. Put repeatable edge cases in Lab mode.
- Make every cartridge work as a complete flat 2D game. Keep collision, controls, rules, and essential clues independent of depth settings.
- Plan frames for Kernelcade's 2.5D presentation. Where the system allows it, keep the playable plane, actors, decorative foreground, background, and HUD distinguishable. Use depth to clarify space. Keep HUD and essential cues stable and readable.
- Keep those layer roles and conservative depth choices usable by future stereo renderers. Treat red/cyan paper-glasses anaglyph as the first stereo experiment. Test color-dependent cues in flat, left-eye, right-eye, and combined views. Keep dedicated stereoscopic glasses as a longer-term target and defer device-specific choices until that hardware and output path are defined.
- Keep Kip's chapters in story order and give each system a different genre. Put the hardware showcase where it helps that chapter, including in optional scenes or Lab when it would distract from play.
