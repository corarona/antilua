# autocraft

Automated crafting GUI that fills the craft grid from inventory and repeatedly crafts items. Recipes are auto-detected when you arrange items on the grid and are persisted via `core.settings`.

## Player usage

**Chat commands:**

- `/autocraft` — Opens the autocraft GUI with a 3×3 craft grid, inventory, and toggle button.
- `/autocraft_list` — Shows all known recipes in a list; click a recipe to select/deselect it.
- `/autocraft_clear` — Clears all stored recipes.

**Cheat:** `Autocraft` (category: Player) — Toggles the `autocraft` setting.

**Recipe persistence:** Recipes survive restarts via `core.settings:get/set("autocraft_recipes")` as JSON.

**Behavior:** While the cheat is on and a recipe is selected, the mod polls the craft grid every 0.3 s: takes the result, refills ingredients from the main inventory, and re-crafts. If ingredients run out, it pauses and reports.

## API

None.

## Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| Autocraft | autocraft | Automated crafting — fills craft grid and repeatedly crafts selected recipes. |
