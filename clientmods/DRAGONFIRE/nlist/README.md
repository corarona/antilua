# nlist

Named, persistent node/item list manager. Provides a UI and chat commands to
create, edit, select, and persist named lists of itemstrings. Integrates with
other mods: lists can be imported into chat commands that expose a
`list_setting` field.

## Player usage

### Chat commands

| Command | Description |
|---------|-------------|
| `/nls <list>` | Select a list by name |
| `/nlshow` | Show current list content as HUD |
| `/nlhide` | Hide the list HUD |
| `/nla [item]` | Add item to selected list (or switch to add mode) |
| `/nlr [item]` | Remove item from selected list (or switch to remove mode) |
| `/nlc` | Clear all items from selected list |
| `/nlawi` | Add wielded itemstring to selected list |
| `/nlrwi` | Remove wielded itemstring from selected list |
| `/nlapn` | Add pointed node's itemstring to selected list |
| `/nlrpn` | Remove pointed node's itemstring from selected list |

### Cheats

| Cheat | Setting | Description |
|-------|---------|-------------|
| NlEdMode | `nlist_edmode` | Shows list HUD; punching a node adds/removes it from the selected list |

NlEdMode provides a custom settings formspec with a textlist showing all
entries, dropdown to select lists, and buttons to create/delete lists or
add/remove entries.

### Integration with other mods

Chat commands that define `list_setting` on their registration are extended
with an `nls` argument. Running `.<command> nls` copies the currently selected
nlist into that command's setting. For example:

```
/xray nls   -- imports current nlist entries into xray's node list
```

## API

### Global

`nlist` — main namespace table.

`nlist.selected` — string, name of the currently selected list.

### Functions

`nlist.add(list, node)` — insert `node` into the named list (if not already present).

`nlist.remove(list, node)` — remove `node` from the named list.

`nlist.set(list, tb)` — replace list contents with `tb` (array of strings). If the list
name matches a `list_setting` on a registered chat command, the value is stored
as a minetest setting; otherwise it uses mod storage.

`nlist.get(list)` — return array of itemstrings for the named list, or `{}`.

`nlist.clear(list)` — empty the named list.

`nlist.delete(list)` — empty the named list (same as clear).

`nlist.select(list)` — set `nlist.selected` (and internal cursor).

`nlist.get_lists()` — return sorted array of all stored list names (from mod storage only).

`nlist.rename(oldname, newname)` — rename a list; returns `true` on success.

`nlist.copy(oldname, newname)` — copy list contents; backs up target if non-empty.

`nlist.random(list)` — return a random item from the list.

`nlist.show_list(list, hlp)` — display list content as HUD text (with optional help header).

`nlist.hide()` — remove the list HUD element.

`nlist.set_nled_hud(ttext)` — create or update the HUD text element displaying list info; returns `true`.
