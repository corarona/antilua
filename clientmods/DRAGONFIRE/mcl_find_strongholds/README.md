# mcl_find_strongholds

Calculates stronghold positions for Minecraft-like (mcl) worlds for a given numeric seed. Uses the standard 8-ring stronghold distribution algorithm and returns positions sorted by distance from the player.

## Player usage

- `/find_strongholds [seed]` — Display all stronghold positions, sorted by distance from the player. If seed is omitted, attempts to retrieve it from `minetest.get_server_info().seed`. Also marks the closest stronghold via the `poi` system.

## Cheats

None. Chat command only — `/find_strongholds [seed]`.

## API

None.
