# nlist

Named, persistent node/item list manager. Provides a UI and chat commands to
create, edit, select, and persist named lists of itemstrings. Integrates with
other mods: lists can be imported into chat commands that expose a
`list_setting` field.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/nl <sub> [args]` | Umbrella command (subcommands below) |
| `/nl select <list>` | Select a list by name |
| `/nl add <item>` | Add item to the selected list |
| `/nl rem <item>` | Remove item from the selected list |
| `/nl toggle <item>` | Toggle item membership in the selected list |
| `/nl show [list]` | Show a list as HUD |
| `/nl new <list>` | Create and select an empty list |
| `/nl delete <list>` | Delete a list |
| `/nl export [list]` | Print a list as CSV to chat |
| `/nl import <list> <csv>` | Bulk-import comma-separated items into a list |
| `/nls <list>` | Select a list by name |
| `/nlshow [list]` | Show a list as HUD without selecting it (defaults to the selected list) |
| `/nlhide` | Hide the list HUD |
| `/nla [item]` | Add item to selected list (or switch to add mode) |
| `/nlr [item]` | Remove item from selected list (or switch to remove mode) |
| `/nlt [item]` | Toggle item in selected list (or switch to toggle mode) |
| `/nlc` | Clear all items from selected list |
| `/nlawi` | Add wielded itemstring to selected list |
| `/nlrwi` | Remove wielded itemstring from selected list |
| `/nlapn` | Add pointed node's itemstring to selected list |
| `/nlrpn` | Remove pointed node's itemstring from selected list |

### Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| NlEdMode | `nlist_edmode` | Shows list HUD; punching a node adds/removes/toggles it in the selected list |

NlEdMode provides a custom settings formspec with:

- Scrollable entry list; known items show their **inventory texture** next to
  the itemstring (and a friendly name), unknown names (e.g. friends/enemies)
  show as plain text rows. Clicking a row applies the current mode
  (add/remove/toggle).
- A **filter** searchbar that matches itemstrings and friendly names.
- A **Pick** panel listing all registered items (also filterable) — click to
  toggle membership. Large registries require a filter before browsing.
- List management: dropdown selection, create, rename (collision-checked), and
  delete/clear behind inline confirmation dialogs.
- Quick actions: cycle mode, add wielded, add pointed, and manual add/remove.
- Add/remove mode is color-coded on the HUD (green/red/orange) and persists
  across restarts.

### Integration with other mods

Chat commands that define `list_setting` on their registration are extended
with an `nls` argument. Running `.<command> nls` **merges** the currently
selected nlist into that command's setting (never clobbers existing entries).
For example:

```
/xray nls   -- imports current nlist entries into xray's node list
```

## API

### Global

`nlist` — main namespace table.

`nlist.selected` — string, name of the currently selected list.

### Functions

`nlist.add(list, node [, silent])` — insert `node` into the named list (if not
already present). Returns `true` on success, `false` on duplicate/empty input.

`nlist.remove(list, node [, silent])` — remove `node` from the named list.
Returns `true` on success.

`nlist.toggle(list, node [, silent])` — add if absent, remove if present.

`nlist.set(list, tb)` — replace list contents with `tb` (array of strings). If the list
name matches a `list_setting` on a registered chat command, the value is stored
as a minetest setting; otherwise it uses mod storage.

`nlist.get(list)` — return array of itemstrings for the named list, or `{}`.

`nlist.count(list)` — number of entries in the named list.

`nlist.clear(list)` — empty the named list.

`nlist.delete(list)` — empty the named list (same as clear).

`nlist.select(list)` — set `nlist.selected` (and internal cursor, persisted).

`nlist.set_mode(mode)` — set edit mode (1=add, 2=remove, 3=toggle, persisted).
Returns the new mode.

`nlist.get_lists()` — return sorted array of all stored list names (from mod storage only).

`nlist.rename(oldname, newname)` — rename a list; returns `true` on success.

`nlist.copy(oldname, newname)` — copy list contents; backs up target if non-empty.

`nlist.merge(dst, src)` — union `src` into `dst` without clobbering existing
entries. Returns the number of new entries added.

`nlist.random(list)` — return a random item from the list.

`nlist.display(name)` — friendly item description for known items, raw name otherwise.

`nlist.show_list(list, hlp)` — display list content as HUD text (with optional help header).

`nlist.hide()` — remove the list HUD element.

`nlist.set_nled_hud(ttext)` — create or update the HUD text element displaying list info; returns `true`.
