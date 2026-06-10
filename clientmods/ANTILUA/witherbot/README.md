# witherbot

Combat automation for mcl worlds. Provides aura-style cheats for player evasion, selective kill-aura against mobs, and wither-skull dodge. Also registers bot definitions via `sbots` for automated mob/player/crystal/item farming.

## Player usage

- **Cheats:**
  - `SafeAura` (category Combat, setting `safeaura`) — Teleports away from nearby non-local players to a safe spot.
  - `SelKillaura` (category Combat, setting `selkillaura`) — Punches nearby objects matching the `obsbot` nlist within range.
  - `EvadeWither` (category Combat, setting `evade_wither`) — Dodges wither projectiles by teleporting to the farthest air node.
- **Registered bots** (via `sbots.register_bot`):
  - `ObsBot`, `PlBot` (player killer), `CrystalBot` (end crystal breaker), `MobsBot`, `HostileMobs`, `ItemBot` (item collector).

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| SafeAura | safeaura | Teleports away from nearby non-local players to a safe spot |
| SelKillaura | selkillaura | Punches nearby objects matching the obsbot nlist within range |
| EvadeWither | evade_wither | Dodges wither projectiles by teleporting to the farthest air node |
| ObsBot | (func) | Automated obsidian-breaking bot |
| PlBot | (func) | Automated player-killer bot |
| CrystalBot | (func) | Automated end crystal-breaking bot |
| MobsBot | (func) | Automated mob-farming bot |
| HostileMobs | (func) | Automated hostile mob-farming bot |
| ItemBot | (func) | Automated item-collecting bot |

## API

None (no direct global exports; all functionality is through the cheat menu and bot system).
