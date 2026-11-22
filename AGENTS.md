# Instructions for AI coding agents (Claude, Gemini/Antigravity, Codex)

Read `README.md`, `shared/docs/RULES.md` and the game's `DESIGN.md` before changing anything.

1. Work on `main` in small commits. CI must stay green (`gh run list`).
2. Everything must be ORIGINAL: no code, art, music, characters or names from existing games.
3. Tools must be permissively licensed (MIT, BSD, zlib, ISC, public domain/CC0). Never copy
   code from GPL/LGPL/MPL or non-commercial projects.
4. No Nintendo/Sega logos, trademarks or console names inside the games. Use Kernelcade's
   labels (Pocket, Pocket Color, 8-Bit, 16-Bit, 16-Bit GEN, Pocket 32).
5. Game Boy builds: `rgbfix -f hg` only (title + checksums), never `-v`/`-f l` (that inserts
   the Nintendo logo).
6. Follow real hardware rules (VRAM only during VBlank/LCD off, OAM via DMA, sprite limits).
7. Comment the code in plain English: the owner is learning from it.
8. Update the game's DESIGN.md (status) and the README table when something lands.
