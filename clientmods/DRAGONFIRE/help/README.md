# help — Centralized Help System for DragonfireClient Mods

Scans all README.md files in the DRAGONFIRE modpack, populates cheat descriptions
on registered cheat definitions, and provides a formspec-based help browser.

## Player usage

Open the help browser via **TAB → Misc → Help** or `/help` chat command.

- Mod index formspec lists all mods with READMEs
- Click a mod to view its full README rendered as plain text
- Back button returns to the mod index
- Scollable textarea for long READMEs

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Help | (func) | Open the help system mod browser |

## API

None. The mod populates `core.cheat_defs[setting].description` for all registered
cheats that have entries in their mod's README `## Cheats` table.
