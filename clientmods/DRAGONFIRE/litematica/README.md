# Litematica for Minetest

by 🇬regon, with copy-paste code from WorldEdit

## Installation

Litematica for Minetest is provided as a client-side mod only. For 
information about how to install client-side mods, see [the
wiki](https://wiki.minetest.net/Installing_Client-Side_Mods).

To be able to use Litematica on a server, the server settings (which also apply
to singleplayer) must allow client modding and must not limit the range on
getting nodes (do not set `LOOKUP_NODES_LIMIT`). If in doubt in singleplayer,
set your `csm_restriction_flags` setting to 0.

## Configuration

* `litematica_file`: Unused. Would be used to load from a file, but file
input/output isn't possible for client-side mods.
* `litematica_output`: Stores the contents of a successful `.litematica_save`
command so it can be restored. If you want to load a WorldEdit schematic from a
file, and that file is too big for the Minetest chat window, then you will
have to paste it in this setting because Minetest client-side mods cannot
actually read from external files with the Lua I/O library like normal server
mods.
* `litematica_node_names`: This is a JSON array of that lists the names of the
nodes that you want to be able to use with Litematica. This list unfortunately
has to be hardcoded because Minetest's client-side API doesn't have any way to
get the tile-textures of nodes, only ancillary info like inventory images and so
on. For every node name, there must be a single corresponding texture name in
`litematica_texture_names`.
* `litematica_texture_names`: This is a JSON array that represents the texture
names of all the nodes listed in `litematica_node_names`. There must be exactly
one texture per node, no more or fewer.

## Usage

The mod allows a local player to load WorldEdit format schematics and show the
nodes as particles in the world as a guide for building. It is quite unstable
and basic but it is at possible to save and restore your own builds for now.

The mod is used purely through chat commands, using the usual prefix `.` for
client-side commands.

* `.liteload`: Loads the file specified, or load $ for the stored schematic in
`litematica_output`. Note: Loading files is though not to work yet.
* `.litepos1`: Set position 1 for saving a schematic, which should be one corner
of the schematic.
* `.litepos2`: Set position 2 for saving the schematic, which should be the
diagonally opposite corner to position 1.
* `.litesave`: Save the nodes between position 1 and position 2 as a WorldEdit
schematic to the setting `litematica_output`, so it can be loaded again easily.

## License

Litematica for Minetest is licensed under the GNU Affero General Public License,
version 3.

Portions copyright (C) 2024 🇬regon

Litematica for Minetest contains significant portions of code from WorldEdit for
Minetest Copyright (C) 2012 sfan5, Anthony Zhang (Uberi/Temperest) and Brett
O'Donnel (cornernote).

This mod is licensed under the [GNU Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.html).

Basically, this means everyone is free to use, modify, and distribute the
files, as long as these modifications are also licensed the same way.
Most importantly, the Affero variant of the GPL requires you to publish your
modifications in source form, even if the mod is run only on the server and
not distributed (note: this is a client-side mode unlike the original
WorldEdit, however, restrictions may still apply, consult the license.
