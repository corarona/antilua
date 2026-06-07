# inv_open

Inventory and crafting GUI tools (merged from open_inv + enderchest + punchinv). Provides a crafting grid formspec, an inventory list viewer for arbitrary player lists and nearby node inventories, and punch-to-open node inventories.

## Player usage

### Cheats

| Cheat | Category | Setting | Description |
|-------|----------|---------|-------------|
| OpenInvLists | Inventory | — | Open the inventory list browser formspec |
| OpenCraftGrid | Inventory | — | Open the portable crafting grid formspec |
| PunchInv | Inventory | `punchinv` | Open a node's inventory when punching it |

### Chat commands

| Command | Description |
|---------|-------------|
| `/craft` | Open a full 3×3 crafting grid formspec |
| `/openlist [listname]` | Open an inventory list browser for the named list (e.g. `main`, `craft`) |

### Settings

- `punchinv` — boolean, enable opening node inventories on punch (default: false)

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| OpenInvLists | — | Open the inventory list browser formspec |
| OpenCraftGrid | — | Open the portable crafting grid formspec |
| PunchInv | `punchinv` | Open a node's inventory when punching it |
