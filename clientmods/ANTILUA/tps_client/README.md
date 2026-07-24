# tps_client

Displays server TPS and client ping in a HUD overlay. Communicates with the server-side `tps` mod via mod channels. Requires the server to have the companion mod installed (https://github.com/ClamityAnarchy/tps).

## Player usage

None — purely passive HUD display.

## API

- `tps_client` — Global table with fields:
  - `tps` — current server TPS (populated via mod channel)
  - `ping` — seconds since last TPS update (accumulated in globalstep, displayed as ms)

## Cheats

None. HUD utility — no cheats registered.