## nlist
More convenient tools to edit the dragonfire lists and to store additional custom lists.

### NlEdMode
Activating this will show you a hud with the currently selected (.nls) list on the right. Punching a node will add (or remove) the itemstring to/from that list.

### Dragonfire listcommand extension
Running a dragonfire listcommand with the nls argument will push the currently selected list to the dragonfire list of that command:

e.g. .xray nls

### Commands

#### .nls listname
Select a list

#### .nla [ item ]
Add an Item to the currently selected list.
Without arguments this switches to "add" mode (default).

#### .nlr [ item ]
Remove an Item from the currently selected list.
Without arguments this switches to "remove" mode.

#### .nlc
Clear all items from the currently selected list.

#### .nlawi
Add the itemstring of the currently wielded item to the selected list.

#### .nlrwi
Remove the itemstring of the currently wielded item from the selected list.

#### .nlapn
Add the itemstring of the currently pointed at node to the selected list.

#### .nlrpn
Remove the itemstring of the currently pointed at node from the selected list.

#### .nlshow listname
Show (without selecting) the list suppiled as argument.

#### .nlhide
Hide the currently shown hud
