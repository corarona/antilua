# sbots

Simple bot library. Provides a framework for creating autonomous bots that fly
to positions and perform actions. Includes one built-in bot (`listDigBot`) when
the `nlist` mod is present. Bots are activated/deactivated via the cheat menu.

No direct player-facing chat commands — bots are registered by other mods and
toggled through the cheat system.

## Player usage

### Cheats

| Cheat | Setting | Category | Description |
|-------|---------|----------|-------------|
| listDigBot | `listDigBot` | Bots | Finds and digs nodes from the currently selected nlist |

Additional bots registered by other mods (e.g. SpongeBot in the `place` mod)
appear under the Bots category.

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `listDigBot.allow_cobot` | bool | false | Allow running alongside other bots |

## API

### Global

`sbots` — main namespace table.

### Functions

`sbots.register_bot(name, def)` — register a new bot. The bot appears as a
cheat under the Bots category with setting name equal to `name`. If another bot
is already active and `allow_cobot` is false, activation is rejected.

### Bot definition

```lua
{
    -- Callbacks (all optional, defaults provided for each):

    find_pos = function(self, pos) end,
    -- Called in stage 0 to find a target position. Return a position vector
    -- or nil/false. pos is the player's current position. When nil is returned
    -- and stand_waiting is false, the bot deactivates itself.

    do_pos = function(self, pos) end,
    -- Called when the bot reaches its target (stage 2). Return true to signal
    -- completion and move to stage 0 (find next target).

    do_step = function(self, dtime) end,
    -- Called every globalstep while the bot is active, regardless of stage.

    update_pos = function(self, pos) return self:find_pos(self, pos) end,
    -- Called every globalstep when moving_target is true to update the
    -- target position mid-flight. Defaults to re-running find_pos.

    on_activate = function(self) end,
    -- Called when the bot is activated. Return true to abort activation.

    on_deactivate = function(self) end,
    -- Called when the bot is deactivated.

    -- Properties:

    landing_distance = 1,
    -- Distance from target at which the bot stops flying and enters stage 2.

    moving_target = false,
    -- Whether the target can move; enables update_pos every tick.

    stand_waiting = false,
    -- If true, the bot stays active even when find_pos returns nil.

    daughters = {},
    -- Sub-settings to toggle with this bot.

    delay = nil,
    -- Override the default hack delay.

    allow_cobot = false,
    -- Set to true in the def to allow concurrent bot operation.

    -- Internal (set at runtime):

    active = false,
    orig_pos = nil,
    target_pos = nil,
    stage = 0,
}
```

### Bot lifecycle

1. **Stage 0**: Calls `find_pos`. If a position is returned, sets `target_pos`
   and transitions to stage 1. If nil and `stand_waiting` is false, deactivates.
2. **Stage 1**: Aims at `target_pos` and enables forward movement. When within
   `landing_distance`, transitions to stage 2.
3. **Stage 2**: Disables forward movement, calls `do_pos`. If `do_pos` returns
   true, transitions back to stage 0.
4. Every tick: calls `do_step`. If `moving_target`, calls `update_pos`.

### Built-in: listDigBot

Registered if `nlist` is available. Finds the closest node from nlist's
selected list within 60m, flies to it, and digs all matching nodes within 1m.

## Cheats

None directly. Bot framework — bots are registered by other mods via sbots.register_bot().
