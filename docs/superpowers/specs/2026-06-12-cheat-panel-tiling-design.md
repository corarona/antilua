# Cheat Layer Panel Tiling — Overlap Fix

## Problem

When opening the cheat layer, category panels often overlap. This happens because:

1. Saved panel positions (`panel_pos__cat_N` settings) accumulate over time.
2. Adding/removing mods changes which categories exist — stale saved positions for removed categories are never purged.
3. When new categories appear, their grid-tiled default positions can conflict with restored saved positions from prior sessions.
4. Pinned panels can fail to restore their position if the overlap check in `autoTilePanels()` falsely detects a conflict (pinned position vs. a newly grid-tiled panel that was tiled *after* the pinned panel's intended spot).

## Design

### Goals

- **Pinned panels always restore** to their saved position — pinning means "keep this exactly where I put it."
- **Unpinned panels auto-arrange** in a clean non-overlapping grid.
- **Adding/removing mods** does not cause cascading position chaos.
- **Minimal diff** — reuse existing `autoTilePanels()` machinery.

### Changes

#### 1. `PanelOverlay::autoTilePanels()` — three-pass layout

**Pass 1 — Restore pinned panels.** Iterate all panels. If a panel has a saved position and is pinned (saved with `,pinned` suffix), restore it unconditionally — no overlap check. Mark it as placed.

**Pass 2 — Grid-tile unpinned panels.** Iterate all panels that were not placed in Pass 1. Tile them left-to-right, top-to-bottom, but treat columns as "slots" that skip over the screen rectangles occupied by pinned panels. This avoids placing a new panel on top of a pinned one.

**Pass 3 — Attempt saved-position restore for unpinned panels.** For each unpinned panel, check if it has a non-zero saved position that does not overlap *any already-placed panel* (pinned or already-restored). If it's clean, restore it. Otherwise keep the grid position from Pass 2.

This replaces the current two-pass approach (grid → overlay saved positions) which had a race condition where two saved positions could both pass the overlap check because they only tested against the initial grid, not against already-restored panels.

#### 2. `CheatMenu::onLayerClosed()` — purge stale positions

After saving current panel positions, iterate the settings matching `panel_pos__cat_*` and delete entries that do not correspond to any current category panel. This prevents accumulation of stale positions for removed mods.

#### 3. `CheatMenu::createCategoryPanels()` — stable order

Already sorted alphabetically. No change needed.

### Files changed

| File | What |
|------|------|
| `src/gui/overlayPanel.cpp` | Rewrite `autoTilePanels()` (3-pass), add helper to check if rect is occupied by pinned panels |
| `src/gui/cheatMenu.cpp` | Add stale-position purge in `onLayerClosed()` |

### Open questions (none)

Design is straightforward and targeted.

### Success criteria

- Open cheat layer → all panels visible, no overlaps.
- Pin a panel → close/reopen → pinned panel exactly where left, unpinned panels fill remaining space without overlap.
- Install a mod that adds new cheat categories → unpinned panels reflow around pinned ones, no overlap.
- Uninstall a mod → stale settings for its categories are cleaned up on next close.
