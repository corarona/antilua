# farmtool

Automated farming tools: harvest, till, sow, and repair farmland. Also provides a FarmBot that autonomously plants seeds on nearby soil.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| Reap | Place | `farmtool_reap` | Harvest mature crops and replant seeds in a radius around the player |
| Till | Place | `farmtool_till` | Till dirt blocks into soil within range using the configured hoe |
| Sow | Place | `farmtool_sow` | Plant the wielded seed on nearby soil blocks |
| FarmRepair | Place | `farmrepair` | Repair water channels and fill holes around water sources |

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `farmtool_reap.range` | 5 (or `ws.range`) | Crop search radius for Reap |
| `farmtool_till.range` | 5 | Till range |
| `farmtool_till.hoe_item` | `mcl_tools:hoe_diamond` | Hoe item to use for tilling |
| `farmtool_sow.range` | 5 (or `ws.range`) | Soil search radius for Sow |
| `farmrepair.range` | 5 | Water source search radius |
| `farmrepair.channel_range` | 5 | Channel repair radius around water |

### FarmBot

Registered via `sbots.register_bot("FarmBot", ...)`. When activated, it autonomously navigates to nearby soil and plants seeds.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Reap | `farmtool_reap` | Harvest mature crops and replant seeds in a radius around the player |
| Till | `farmtool_till` | Till dirt blocks into soil within range using the configured hoe |
| Sow | `farmtool_sow` | Plant the wielded seed on nearby soil blocks |
| FarmRepair | `farmrepair` | Repair water channels and fill holes around water sources |
| FarmBot | — | Autonomous bot that navigates to soil and plants seeds (registered via sbots) |
