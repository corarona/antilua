# invutil

Inventory utility tools: auto-refill wielded item stacks, auto-eject unwanted items, dump a pointed container's inventory, and auto-craft blocks from full stacks.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| AutoRefill | Inventory | `autorefill` | Automatically refill the wielded item from other inventory stacks when it runs low |
| AutoEject | Inventory | `autoeject` | Automatically drop items whose names match the eject list |
| DumpFull | Inventory | — | Dump entire player inventory into the pointed container |
| AutoBlock | Inventory | `autoblock` | Auto-craft block items from full stacks of their constituent materials (e.g. diamond → diamond block) |

### Chat commands

| Command | Description |
|---------|-------------|
| `/list eject [items]` | Configure AutoEject item list (comma-separated item names) |

### Settings

- `autorefill` — boolean, enable auto-refill
- `autoeject` — boolean, enable auto-eject
- `eject_items` — comma-separated list of item names to auto-drop

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| AutoRefill | `autorefill` | Automatically refill the wielded item from other inventory stacks when it runs low |
| AutoEject | `autoeject` | Automatically drop items whose names match the eject list |
| DumpFull | — | Dump entire player inventory into the pointed container |
| AutoBlock | `autoblock` | Auto-craft block items from full stacks of their constituent materials |
