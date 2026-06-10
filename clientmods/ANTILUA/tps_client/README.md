# tps_client

Displays server TPS and client ping in a HUD overlay. Communicates with the server-side `tps` mod via mod channels. Requires the server to have the companion mod installed (https://github.com/ClamityAnarchy/tps).

## Player usage

- **Chat commands:**
  - `/tps_set_ping_tolerance <n>` — Set `tps_client.ping_tolerance` (default 0.5)
  - `/tps_set_tps_tolerance <n>` — Set `tps_client.tps_tolerance` (default 10)

## API

- `tps_client` — Global table with fields:
  - `tps` — current server TPS (populated via mod channel)
  - `ping` — current ping in seconds (accumulated in globalstep)
  - `ping_tolerance` — tolerance threshold for ping (default 0.5)
  - `tps_tolerance` — tolerance threshold for TPS (default 10)

## Cheats

None. HUD utility — no cheats registered.
