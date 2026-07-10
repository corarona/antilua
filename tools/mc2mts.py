#!/usr/bin/env python3
"""
mc2mts — Convert Minecraft .schematic files to Luanti .mts format.

Usage:
    python mc2mts.py input.schematic output.mts

The .schematic format (MCEdit/WorldEdit) is a GZip-compressed NBT structure.
Block mappings are derived from the MC2MT project (Mineclonia target).
"""

import argparse
import struct
import zlib
import gzip
import sys
import os
from collections import OrderedDict

# ── NBT Parser ──────────────────────────────────────────────────────────────

TAG_END = 0
TAG_BYTE = 1
TAG_SHORT = 2
TAG_INT = 3
TAG_LONG = 4
TAG_FLOAT = 5
TAG_DOUBLE = 6
TAG_BYTE_ARRAY = 7
TAG_STRING = 8
TAG_LIST = 9
TAG_COMPOUND = 10
TAG_INT_ARRAY = 11


class NBT:
    def __init__(self, data):
        self.data = data
        self.offset = 0

    def read_byte(self):
        v = self.data[self.offset]
        self.offset += 1
        return v

    def read_short(self):
        v = struct.unpack_from('>h', self.data, self.offset)[0]
        self.offset += 2
        return v

    def read_ushort(self):
        v = struct.unpack_from('>H', self.data, self.offset)[0]
        self.offset += 2
        return v

    def read_int(self):
        v = struct.unpack_from('>i', self.data, self.offset)[0]
        self.offset += 4
        return v

    def read_string(self):
        length = self.read_ushort()
        s = self.data[self.offset:self.offset + length]
        self.offset += length
        return s.decode('utf-8')

    def parse(self, named=True):
        tag_type = self.read_byte()
        if tag_type == TAG_END:
            return ('', None)
        name = ''
        if named:
            name = self.read_string()
        if tag_type == TAG_BYTE:
            return (name, self.read_byte())
        elif tag_type == TAG_SHORT:
            return (name, self.read_short())
        elif tag_type == TAG_INT:
            return (name, self.read_int())
        elif tag_type == TAG_LONG:
            v = struct.unpack_from('>q', self.data, self.offset)[0]
            self.offset += 8
            return (name, v)
        elif tag_type == TAG_FLOAT:
            v = struct.unpack_from('>f', self.data, self.offset)[0]
            self.offset += 4
            return (name, v)
        elif tag_type == TAG_DOUBLE:
            v = struct.unpack_from('>d', self.data, self.offset)[0]
            self.offset += 8
            return (name, v)
        elif tag_type == TAG_BYTE_ARRAY:
            length = self.read_int()
            data = self.data[self.offset:self.offset + length]
            self.offset += length
            return (name, data)
        elif tag_type == TAG_STRING:
            return (name, self.read_string())
        elif tag_type == TAG_LIST:
            elem_type = self.read_byte()
            length = self.read_int()
            items = []
            for _ in range(length):
                if elem_type == TAG_COMPOUND:
                    items.append(self.parse_compound())
                elif elem_type == TAG_BYTE:
                    items.append(self.read_byte())
                elif elem_type == TAG_SHORT:
                    items.append(self.read_short())
                elif elem_type == TAG_INT:
                    items.append(self.read_int())
                elif elem_type == TAG_STRING:
                    items.append(self.read_string())
                elif elem_type == TAG_BYTE_ARRAY:
                    l = self.read_int()
                    items.append(self.data[self.offset:self.offset + l])
                    self.offset += l
                elif elem_type == TAG_INT_ARRAY:
                    l = self.read_int()
                    arr = struct.unpack_from('>' + 'i' * l, self.data, self.offset)
                    self.offset += l * 4
                    items.append(list(arr))
                else:
                    raise ValueError(f"Unsupported list element type {elem_type}")
            return (name, items)
        elif tag_type == TAG_COMPOUND:
            return (name, self.parse_compound())
        elif tag_type == TAG_INT_ARRAY:
            length = self.read_int()
            vals = struct.unpack_from('>' + 'i' * length, self.data, self.offset)
            self.offset += length * 4
            return (name, list(vals))
        else:
            raise ValueError(f"Unknown NBT tag type {tag_type}")

    def parse_compound(self):
        obj = OrderedDict()
        while self.data[self.offset] != TAG_END:
            name, value = self.parse()
            obj[name] = value
        self.offset += 1
        return obj


# ── MTS Writer ──────────────────────────────────────────────────────────────

MTSCHEM_SIGNATURE = 0x4D54534D
MTSCHEM_VERSION = 4
MTSCHEM_PROB_ALWAYS = 0x7F


def write_mts(path, size_x, size_y, size_z, nodes):
    """
    nodes: list of (name, param2) tuples in YZX order (Minecraft schematic).
    Reorders to ZYX (MTS order) internally.
    """
    total = size_x * size_y * size_z
    assert len(nodes) == total

    name_ids = OrderedDict()
    for name, _ in nodes:
        if name not in name_ids:
            name_ids[name] = len(name_ids)

    buf = bytearray()
    buf += struct.pack('>I', MTSCHEM_SIGNATURE)
    buf += struct.pack('>H', MTSCHEM_VERSION)
    buf += struct.pack('>H', size_x)
    buf += struct.pack('>H', size_y)
    buf += struct.pack('>H', size_z)
    for _ in range(size_y):
        buf += struct.pack('B', MTSCHEM_PROB_ALWAYS)
    buf += struct.pack('>H', len(name_ids))
    for name in name_ids:
        encoded = name.encode('utf-8')
        buf += struct.pack('>H', len(encoded))
        buf += encoded

    bulk = bytearray()
    for z in range(size_z):
        for y in range(size_y):
            for x in range(size_x):
                mc_idx = y * size_z * size_x + z * size_x + x
                name, param2 = nodes[mc_idx]
                cid = name_ids[name]
                bulk += struct.pack('>H', cid)
                bulk += struct.pack('B', MTSCHEM_PROB_ALWAYS)
                bulk += struct.pack('B', param2)
    buf += zlib.compress(bytes(bulk))

    with open(path, 'wb') as f:
        f.write(buf)


# ── Block Mappings ──────────────────────────────────────────────────────────

BLOCK_MAP = {}


def _map_all(id, name, param2=0):
    for d in range(16):
        BLOCK_MAP[(id, d)] = (name, param2)


def _map(id, data, name, param2=0):
    if isinstance(data, tuple):
        for d in data:
            BLOCK_MAP[(id, d)] = (name, param2)
    else:
        BLOCK_MAP[(id, data)] = (name, param2)


def _stair(id, mtn):
    _map(id, 0, mtn, 1); _map(id, 1, mtn, 3); _map(id, 2, mtn, 2); _map(id, 3, mtn, 0)
    _map(id, 4, mtn, 23); _map(id, 5, mtn, 21); _map(id, 6, mtn, 22); _map(id, 7, mtn, 20)


def _slab(id, dbottom, dtop, mtn):
    _map(id, dbottom, mtn, 0); _map(id, dtop, mtn, 22)


def _log(id, base_data, mtn):
    _map(id, base_data, mtn, 0)
    _map(id, base_data + 4, mtn, 12)
    _map(id, base_data + 8, mtn, 4)
    _map(id, base_data + 12, mtn, 0)


def _trapdoor(id, mtn):
    _map(id, 0, mtn, 2); _map(id, 1, mtn, 0); _map(id, 2, mtn, 1); _map(id, 3, mtn, 3)
    _map(id, 4, mtn + '_open', 2); _map(id, 5, mtn + '_open', 0)
    _map(id, 6, mtn + '_open', 1); _map(id, 7, mtn + '_open', 3)
    _map(id, 8, mtn, 22); _map(id, 9, mtn, 20); _map(id, 10, mtn, 23); _map(id, 11, mtn, 21)
    _map(id, 12, mtn + '_open', 22); _map(id, 13, mtn + '_open', 20)
    _map(id, 14, mtn + '_open', 23); _map(id, 15, mtn + '_open', 21)


def _gate(id, mtn):
    _map(id, 0, mtn + '_closed', 0); _map(id, 1, mtn + '_closed', 2)
    _map(id, 2, mtn + '_closed', 3); _map(id, 3, mtn + '_closed', 1)
    _map(id, 4, mtn + '_open', 0); _map(id, 5, mtn + '_open', 2)
    _map(id, 6, mtn + '_open', 3); _map(id, 7, mtn + '_open', 1)


def _door(id, mtn):
    _map(id, 0, mtn + '_b_1', 1); _map(id, 1, mtn + '_b_1', 2)
    _map(id, 2, mtn + '_b_1', 3); _map(id, 3, mtn + '_b_1', 0)
    _map(id, 4, mtn + '_b_2', 5); _map(id, 5, mtn + '_b_2', 6)
    _map(id, 6, mtn + '_b_2', 7); _map(id, 7, mtn + '_b_2', 4)
    _map(id, (8, 9, 10, 11, 12, 13, 14, 15), mtn + '_t_1')


# ── Populate mappings ──

# Block IDs 0-99
_map_all(0, 'air')
_map(1, 0, 'mcl_core:stone')
_map(1, 1, 'mcl_core:granite')
_map(1, 2, 'mcl_core:granite_smooth')
_map(1, 3, 'mcl_core:diorite')
_map(1, 4, 'mcl_core:diorite_smooth')
_map(1, 5, 'mcl_core:andesite')
_map(1, 6, 'mcl_core:andesite_smooth')
_map_all(2, 'mcl_core:dirt_with_grass')
_map(3, 0, 'mcl_core:dirt')
_map(3, 1, 'mcl_core:coarse_dirt')
_map(3, 2, 'mcl_core:podzol')
_map_all(4, 'mcl_core:cobble')
_map(5, 0, 'mcl_trees:wood_oak')
_map(5, 1, 'mcl_trees:wood_spruce')
_map(5, 2, 'mcl_trees:wood_birch')
_map(5, 3, 'mcl_trees:wood_jungle')
_map(5, 4, 'mcl_trees:wood_acacia')
_map(5, 5, 'mcl_trees:wood_dark_oak')
_map(6, (0, 8), 'mcl_trees:sapling_oak')
_map(6, (1, 9), 'mcl_trees:sapling_spruce')
_map(6, (2, 10), 'mcl_trees:sapling_birch')
_map(6, (3, 11), 'mcl_trees:sapling_jungle')
_map(6, (4, 12), 'mcl_trees:sapling_acacia')
_map(6, (5, 13), 'mcl_trees:sapling_dark_oak')
_map_all(7, 'mcl_core:bedrock')
_map_all(8, 'mcl_core:water_flowing')
_map_all(9, 'mcl_core:water_source')
_map_all(10, 'mcl_core:lava_flowing')
_map_all(11, 'mcl_core:lava_source')
_map(12, 0, 'mcl_core:sand')
_map(12, 1, 'mcl_core:redsand')
_map_all(13, 'mcl_core:gravel')
_map_all(14, 'mcl_core:stone_with_gold')
_map_all(15, 'mcl_core:stone_with_iron')
_map_all(16, 'mcl_core:stone_with_coal')
_log(17, 0, 'mcl_trees:tree_oak')
_log(17, 1, 'mcl_trees:tree_spruce')
_log(17, 2, 'mcl_trees:tree_birch')
_log(17, 3, 'mcl_trees:tree_jungle')
_map(18, (0, 8), 'mcl_trees:leaves_oak')
_map(18, (1, 9), 'mcl_trees:leaves_spruce')
_map(18, (2, 10), 'mcl_trees:leaves_birch')
_map(18, (3, 11), 'mcl_trees:leaves_jungle')
_map(18, (4, 12), 'mcl_trees:leaves_oak', 1)
_map(18, (5, 13), 'mcl_trees:leaves_spruce', 1)
_map(18, (6, 14), 'mcl_trees:leaves_birch', 1)
_map(18, (7, 15), 'mcl_trees:leaves_jungle', 1)
_map(19, 0, 'mcl_sponges:sponge')
_map(19, 1, 'mcl_sponges:sponge_wet')
_map_all(20, 'mcl_core:glass')
_map_all(21, 'mcl_core:stone_with_lapis')
_map_all(22, 'mcl_core:lapisblock')
_map(24, 0, 'mcl_core:sandstone')
_map(24, 1, 'mcl_core:sandstonecarved')
_map(24, 2, 'mcl_core:sandstonesmooth')
_map_all(25, 'mesecons_noteblock:noteblock')
_map(26, (0, 4), 'mcl_beds:bed_red_bottom', 2)
_map(26, (1, 5), 'mcl_beds:bed_red_bottom', 3)
_map(26, (2, 6), 'mcl_beds:bed_red_bottom', 1)
_map(26, (3, 7), 'mcl_beds:bed_red_bottom', 1)
_map(26, (8, 12), 'mcl_beds:bed_red_top', 2)
_map(26, (9, 13), 'mcl_beds:bed_red_top', 3)
_map(26, (10, 14), 'mcl_beds:bed_red_top', 0)
_map(26, (11, 15), 'mcl_beds:bed_red_top', 1)
_map_all(27, 'mcl_minecarts:golden_rail')
_map_all(28, 'mcl_minecarts:detector_rail')
_map(29, 0, 'mesecons_pistons:piston_down_sticky_off')
_map(29, 1, 'mesecons_pistons:piston_up_sticky_off')
_map(29, 2, 'mesecons_pistons:piston_sticky_off', 0)
_map(29, 3, 'mesecons_pistons:piston_sticky_off', 2)
_map(29, 4, 'mesecons_pistons:piston_sticky_off', 3)
_map(29, 5, 'mesecons_pistons:piston_sticky_off', 1)
_map(29, 8, 'mesecons_pistons:piston_down_sticky_on')
_map(29, 9, 'mesecons_pistons:piston_up_sticky_on')
_map(29, 10, 'mesecons_pistons:piston_sticky_on', 0)
_map(29, 11, 'mesecons_pistons:piston_sticky_on', 2)
_map(29, 12, 'mesecons_pistons:piston_sticky_on', 3)
_map(29, 13, 'mesecons_pistons:piston_sticky_on', 1)
_map_all(30, 'mcl_core:cobweb')
_map(31, 0, 'mcl_core:deadbush')
_map(31, 1, 'mcl_flowers:tallgrass')
_map(31, 2, 'mcl_flowers:fern')
_map_all(32, 'mcl_core:deadbush')
_map(33, 0, 'mesecons_piston:piston_down_normal_off')
_map(33, 1, 'mesecons_piston:piston_up_normal_off')
_map(33, 2, 'mesecons_piston:piston_normal_off', 0)
_map(33, 3, 'mesecons_piston:piston_normal_off', 2)
_map(33, 4, 'mesecons_piston:piston_normal_off', 3)
_map(33, 5, 'mesecons_piston:piston_normal_off', 1)
_map(33, 8, 'mesecons_piston:piston_down_normal_on')
_map(33, 9, 'mesecons_piston:piston_up_normal_on')
_map(33, 10, 'mesecons_piston:piston_normal_on', 0)
_map(33, 11, 'mesecons_piston:piston_normal_on', 2)
_map(33, 12, 'mesecons_piston:piston_normal_on', 3)
_map(33, 13, 'mesecons_piston:piston_normal_on', 1)
_map(34, 0, 'mesecons_piston:piston_down_pusher_normal')
_map(34, 1, 'mesecons_piston:piston_up_pusher_normal')
_map(34, 2, 'mesecons_piston:piston_pusher_normal', 0)
_map(34, 3, 'mesecons_piston:piston_pusher_normal', 2)
_map(34, 4, 'mesecons_piston:piston_pusher_normal', 3)
_map(34, 5, 'mesecons_piston:piston_pusher_normal', 1)
_map(34, 8, 'mesecons_piston:piston_down_pusher_sticky')
_map(34, 9, 'mesecons_piston:piston_up_pusher_sticky')
_map(34, 10, 'mesecons_piston:piston_pusher_sticky', 0)
_map(34, 11, 'mesecons_piston:piston_pusher_sticky', 2)
_map(34, 12, 'mesecons_piston:piston_pusher_sticky', 3)
_map(34, 13, 'mesecons_piston:piston_pusher_sticky', 1)
_map(35, 0, 'mcl_wool:white')
_map(35, 1, 'mcl_wool:orange')
_map(35, 2, 'mcl_wool:magenta')
_map(35, 3, 'mcl_wool:light_blue')
_map(35, 4, 'mcl_wool:yellow')
_map(35, 5, 'mcl_wool:lime')
_map(35, 6, 'mcl_wool:pink')
_map(35, 7, 'mcl_wool:grey')
_map(35, 8, 'mcl_wool:silver')
_map(35, 9, 'mcl_wool:cyan')
_map(35, 10, 'mcl_wool:purple')
_map(35, 11, 'mcl_wool:blue')
_map(35, 12, 'mcl_wool:brown')
_map(35, 13, 'mcl_wool:green')
_map(35, 14, 'mcl_wool:red')
_map(35, 15, 'mcl_wool:black')
_map_all(37, 'mcl_flowers:dandelion')
_map(38, 0, 'mcl_flowers:poppy')
_map(38, 1, 'mcl_flowers:blue_orchid')
_map(38, 2, 'mcl_flowers:allium')
_map(38, 3, 'mcl_flowers:azure_bluet')
_map(38, 4, 'mcl_flowers:tulip_red')
_map(38, 5, 'mcl_flowers:tulip_orange')
_map(38, 6, 'mcl_flowers:tulip_white')
_map(38, 7, 'mcl_flowers:tulip_pink')
_map(38, 8, 'mcl_flowers:oxeye_daisy')
_map_all(39, 'mcl_mushrooms:mushroom_brown')
_map_all(40, 'mcl_mushrooms:mushroom_red')
_map_all(41, 'mcl_core:goldblock')
_map_all(42, 'mcl_core:ironblock')
_map(43, 0, 'mcl_stairs:slab_stone_double')
_map(43, 1, 'mcl_core:sandstone')
_map(43, 2, 'mcl_trees:wood_oak')
_map(43, 3, 'mcl_core:cobble')
_map(43, 4, 'mcl_core:brick_block')
_map(43, 5, 'mcl_core:stonebrick')
_map(43, 6, 'mcl_nether:nether_brick')
_map(43, 7, 'mcl_nether:quartz_block')
_map(43, 8, 'mcl_core:stone_smooth')
_map(43, 9, 'mcl_core:sandstone')
_map(43, 10, 'mcl_nether:quartz_chiseled')
_slab(44, 0, 8, 'mcl_stairs:slab_stone')
_slab(44, 1, 9, 'mcl_stairs:slab_sandstone')
_slab(44, 2, 10, 'mcl_stairs:slab_oak')
_slab(44, 3, 11, 'mcl_stairs:slab_cobble')
_slab(44, 4, 12, 'mcl_stairs:slab_brick_block')
_slab(44, 5, 13, 'mcl_stairs:slab_stonebrick')
_slab(44, 6, 14, 'mcl_stairs:slab_nether_brick')
_slab(44, 7, 15, 'mcl_stairs:slab_quartzblock')
_map_all(45, 'mcl_core:brick_block')
_map_all(46, 'mcl_tnt:tnt')
_map_all(47, 'mcl_books:bookshelf')
_map_all(48, 'mcl_core:mossycobble')
_map_all(49, 'mcl_core:obsidian')
_map(50, 0, 'mcl_torches:torch', 1)
_map(50, 1, 'mcl_torches:torch_wall', 3)
_map(50, 2, 'mcl_torches:torch_wall', 2)
_map(50, 3, 'mcl_torches:torch_wall', 4)
_map(50, 4, 'mcl_torches:torch_wall', 5)
_map(50, 5, 'mcl_torches:torch', 1)
_map_all(51, 'mcl_fire:fire')
_map_all(52, 'mcl_mobspawners:spawner')
_stair(53, 'mcl_stairs:stair_oak')
_map(54, 2, 'mcl_chests:chest', 0)
_map(54, 3, 'mcl_chests:chest', 2)
_map(54, 4, 'mcl_chests:chest', 3)
_map(54, 5, 'mcl_chests:chest', 1)
_map(55, 0, 'mesecons:wire_00000000_off')
_map(55, (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15), 'mesecons:wire_00000000_on')
_map_all(56, 'mcl_core:stone_with_diamond')
_map_all(57, 'mcl_core:diamondblock')
_map_all(58, 'mcl_crafting_table:crafting_table')
_map(59, 0, 'mcl_farming:wheat_1')
_map(59, 1, 'mcl_farming:wheat_2')
_map(59, 2, 'mcl_farming:wheat_3')
_map(59, 3, 'mcl_farming:wheat_4')
_map(59, 4, 'mcl_farming:wheat_5')
_map(59, 5, 'mcl_farming:wheat_6')
_map(59, 6, 'mcl_farming:wheat_7')
_map(59, 7, 'mcl_farming:wheat')
_map_all(60, 'mcl_farming:soil')
_map(60, 7, 'mcl_farming:soil_wet')
_map(61, 2, 'mcl_furnaces:furnace', 0)
_map(61, 3, 'mcl_furnaces:furnace', 2)
_map(61, 4, 'mcl_furnaces:furnace', 3)
_map(61, 5, 'mcl_furnaces:furnace', 1)
_map(62, 2, 'mcl_furnaces:furnace_active', 0)
_map(62, 3, 'mcl_furnaces:furnace_active', 2)
_map(62, 4, 'mcl_furnaces:furnace_active', 3)
_map(62, 5, 'mcl_furnaces:furnace_active', 1)
_map_all(63, 'mcl_signs:standing_sign', 1)
_door(64, 'mcl_doors:door_oak')
_map(65, 2, 'mcl_core:ladder', 5)
_map(65, 3, 'mcl_core:ladder', 4)
_map(65, 4, 'mcl_core:ladder', 2)
_map(65, 5, 'mcl_core:ladder', 3)
_map_all(66, 'mcl_minecarts:rail')
_stair(67, 'mcl_stairs:stair_cobble')
_map(68, 2, 'mcl_signs:wall_sign', 5)
_map(68, 3, 'mcl_signs:wall_sign', 4)
_map(68, 4, 'mcl_signs:wall_sign', 2)
_map(68, 5, 'mcl_signs:wall_sign', 3)
_map(69, 1, 'mesecons_walllever:wall_lever_off', 1)
_map(69, 2, 'mesecons_walllever:wall_lever_off', 3)
_map(69, 3, 'mesecons_walllever:wall_lever_off', 2)
_map(69, (0, 4, 5, 6, 7), 'mesecons_walllever:wall_lever_off', 0)
_map(69, 9, 'mesecons_walllever:wall_lever_on', 1)
_map(69, 10, 'mesecons_walllever:wall_lever_on', 3)
_map(69, 11, 'mesecons_walllever:wall_lever_on', 2)
_map(69, (8, 12, 13, 14, 15), 'mesecons_walllever:wall_lever_on', 0)
_map_all(70, 'mesecons_pressureplates:pressure_plate_stone_off')
_door(71, 'mcl_doors:iron_door')
_map_all(72, 'mesecons_pressureplates:pressure_plate_oak_off')
_map_all(73, 'mcl_core:stone_with_redstone')
_map_all(74, 'mcl_core:stone_with_redstone_lit')
_map(75, 0, 'mesecons_torch:mesecon_torch_off', 0)
_map(75, 1, 'mesecons_torch:mesecon_torch_off', 5)
_map(75, 2, 'mesecons_torch:mesecon_torch_off', 3)
_map(75, 3, 'mesecons_torch:mesecon_torch_off', 2)
_map(75, 4, 'mesecons_torch:mesecon_torch_off', 4)
_map(75, 5, 'mesecons_torch:mesecon_torch_off', 1)
_map(76, 0, 'mesecons_torch:mesecon_torch_on', 0)
_map(76, 1, 'mesecons_torch:mesecon_torch_on', 5)
_map(76, 2, 'mesecons_torch:mesecon_torch_on', 3)
_map(76, 3, 'mesecons_torch:mesecon_torch_on', 2)
_map(76, 4, 'mesecons_torch:mesecon_torch_on', 4)
_map(76, 5, 'mesecons_torch:mesecon_torch_on', 1)
_map(77, (0, 1, 5, 8, 9, 13), 'mesecons_button:button_off', 1)
_map(77, (2, 10), 'mesecons_button:button_off', 3)
_map(77, (3, 11), 'mesecons_button:button_off', 2)
_map(77, (4, 12), 'mesecons_button:button_off', 0)
_map(78, 0, 'mcl_core:snow')
_map(78, 1, 'mcl_core:snow_2')
_map(78, 2, 'mcl_core:snow_3')
_map(78, 3, 'mcl_core:snow_4')
_map(78, 4, 'mcl_core:snow_5')
_map(78, 5, 'mcl_core:snow_6')
_map(78, 6, 'mcl_core:snow_7')
_map(78, 7, 'mcl_core:snow_8')
_map_all(79, 'mcl_core:ice')
_map_all(80, 'mcl_core:snowblock')
_map_all(81, 'mcl_core:cactus')
_map_all(82, 'mcl_core:clay')
_map_all(83, 'mcl_core:reeds')
_map_all(84, 'mcl_jukebox:jukebox')
_map_all(85, 'mcl_fences:oak_fence')
_map(86, 0, 'mcl_farming:pumpkin_face', 0)
_map(86, 1, 'mcl_farming:pumpkin_face', 1)
_map(86, 2, 'mcl_farming:pumpkin_face', 2)
_map(86, 3, 'mcl_farming:pumpkin_face', 3)
_map_all(87, 'mcl_nether:netherrack')
_map_all(88, 'mcl_nether:soul_sand')
_map_all(89, 'mcl_nether:glowstone')
_map_all(90, 'mcl_portals:portal')
_map(91, (0, 4), 'mcl_farming:pumpkin_face_light', 0)
_map(91, (1, 5), 'mcl_farming:pumpkin_face_light', 1)
_map(91, (2, 6), 'mcl_farming:pumpkin_face_light', 2)
_map(91, (3, 7), 'mcl_farming:pumpkin_face_light', 3)
_map(92, 0, 'mcl_cake:cake')
_map(92, 1, 'mcl_cake:cake_6')
_map(92, 2, 'mcl_cake:cake_5')
_map(92, 3, 'mcl_cake:cake_4')
_map(92, 4, 'mcl_cake:cake_3')
_map(92, 5, 'mcl_cake:cake_2')
_map(92, 6, 'mcl_cake:cake_1')
_map(93, 0, 'mesecons_delayer:delayer_off_1', 1)
_map(93, 1, 'mesecons_delayer:delayer_off_1', 2)
_map(93, 2, 'mesecons_delayer:delayer_off_1', 3)
_map(93, 3, 'mesecons_delayer:delayer_off_1', 0)
_map(93, 4, 'mesecons_delayer:delayer_off_2', 1)
_map(93, 5, 'mesecons_delayer:delayer_off_2', 2)
_map(93, 6, 'mesecons_delayer:delayer_off_2', 3)
_map(93, 7, 'mesecons_delayer:delayer_off_2', 0)
_map(93, 8, 'mesecons_delayer:delayer_off_3', 1)
_map(93, 9, 'mesecons_delayer:delayer_off_3', 2)
_map(93, 10, 'mesecons_delayer:delayer_off_3', 3)
_map(93, 11, 'mesecons_delayer:delayer_off_3', 0)
_map(93, 12, 'mesecons_delayer:delayer_off_4', 1)
_map(93, 13, 'mesecons_delayer:delayer_off_4', 2)
_map(93, 14, 'mesecons_delayer:delayer_off_4', 3)
_map(93, 15, 'mesecons_delayer:delayer_off_4', 0)
_map(94, 0, 'mesecons_delayer:delayer_on_1', 1)
_map(94, 1, 'mesecons_delayer:delayer_on_1', 2)
_map(94, 2, 'mesecons_delayer:delayer_on_1', 3)
_map(94, 3, 'mesecons_delayer:delayer_on_1', 0)
_map(94, 4, 'mesecons_delayer:delayer_on_2', 1)
_map(94, 5, 'mesecons_delayer:delayer_on_2', 2)
_map(94, 6, 'mesecons_delayer:delayer_on_2', 3)
_map(94, 7, 'mesecons_delayer:delayer_on_2', 0)
_map(94, 8, 'mesecons_delayer:delayer_on_3', 1)
_map(94, 9, 'mesecons_delayer:delayer_on_3', 2)
_map(94, 10, 'mesecons_delayer:delayer_on_3', 3)
_map(94, 11, 'mesecons_delayer:delayer_on_3', 0)
_map(94, 12, 'mesecons_delayer:delayer_on_4', 1)
_map(94, 13, 'mesecons_delayer:delayer_on_4', 2)
_map(94, 14, 'mesecons_delayer:delayer_on_4', 3)
_map(94, 15, 'mesecons_delayer:delayer_on_4', 0)
_map(95, 0, 'mcl_core:glass_white')
_map(95, 1, 'mcl_core:glass_orange')
_map(95, 2, 'mcl_core:glass_magenta')
_map(95, 3, 'mcl_core:glass_light_blue')
_map(95, 4, 'mcl_core:glass_yellow')
_map(95, 5, 'mcl_core:glass_lime')
_map(95, 6, 'mcl_core:glass_pink')
_map(95, 7, 'mcl_core:glass_gray')
_map(95, 8, 'mcl_core:glass_silver')
_map(95, 9, 'mcl_core:glass_cyan')
_map(95, 10, 'mcl_core:glass_purple')
_map(95, 11, 'mcl_core:glass_blue')
_map(95, 12, 'mcl_core:glass_brown')
_map(95, 13, 'mcl_core:glass_green')
_map(95, 14, 'mcl_core:glass_red')
_map(95, 15, 'mcl_core:glass_black')
_trapdoor(96, 'mcl_doors:trapdoor')
_map(97, 0, 'mcl_monster_eggs:monster_egg_stone')
_map(97, 1, 'mcl_monster_eggs:monster_egg_cobble')
_map(97, 2, 'mcl_monster_eggs:monster_egg_stonebrick')
_map(97, 3, 'mcl_monster_eggs:monster_egg_stonebrickmossy')
_map(97, 4, 'mcl_monster_eggs:monster_egg_stonebrickcracked')
_map(97, 5, 'mcl_monster_eggs:monster_egg_stonebrickcarved')
_map(98, 0, 'mcl_core:stonebrick')
_map(98, 1, 'mcl_core:stonebrickmossy')
_map(98, 2, 'mcl_core:stonebrickcracked')
_map(98, 3, 'mcl_core:stonebrickcarved')

# Block IDs 100-199
_map_all(101, 'mcl_panes:bar')
_map_all(102, 'mcl_panes:pane_natural')
_map_all(103, 'mcl_farming:melon')
_map_all(106, 'mcl_core:vine')
_gate(107, 'mcl_fences:oak_fence_gate')
_stair(108, 'mcl_stairs:stair_brick_block')
_stair(109, 'mcl_stairs:stair_stonebrick')
_map_all(110, 'mcl_core:mycelium')
_map_all(111, 'mcl_flowers:waterlily')
_map_all(112, 'mcl_nether:nether_brick')
_map_all(113, 'mcl_fences:nether_brick_fence')
_stair(114, 'mcl_stairs:stair_nether_brick')
_map(118, 0, 'mcl_cauldrons:cauldron')
_map(118, 1, 'mcl_cauldrons:cauldron_1')
_map(118, 2, 'mcl_cauldrons:cauldron_2')
_map(118, 3, 'mcl_cauldrons:cauldron_3')
_map_all(119, 'mcl_portals:portal_end')
_map_all(121, 'mcl_end:end_stone')
_map_all(122, 'mcl_end:dragon_egg')
_map_all(123, 'mesecons_lightstone:lightstone_off')
_map_all(124, 'mesecons_lightstone:lightstone_on')
_map(125, 0, 'mcl_trees:wood_oak')
_map(125, 1, 'mcl_trees:wood_spruce')
_map(125, 2, 'mcl_trees:wood_birch')
_map(125, 3, 'mcl_trees:wood_jungle')
_map(125, 4, 'mcl_trees:wood_acacia')
_map(125, 5, 'mcl_trees:wood_dark_oak')
_slab(126, 0, 8, 'mcl_stairs:slab_oak')
_slab(126, 1, 9, 'mcl_stairs:slab_spruce')
_slab(126, 2, 10, 'mcl_stairs:slab_birch')
_slab(126, 3, 11, 'mcl_stairs:slab_jungle')
_slab(126, 4, 12, 'mcl_stairs:slab_acacia')
_slab(126, 5, 13, 'mcl_stairs:slab_dark_oak')
_stair(128, 'mcl_stairs:stair_sandstone')
_map_all(129, 'mcl_core:stone_with_emerald')
_map_all(133, 'mcl_core:emeraldblock')
_stair(134, 'mcl_stairs:stair_spruce')
_stair(135, 'mcl_stairs:stair_birch')
_stair(136, 'mcl_stairs:stair_jungle')
_map_all(137, 'mesecons_commandblock:commandblock_off')
_map(139, 0, 'mcl_walls:cobble')
_map(139, 1, 'mcl_walls:mossycobble')
_map(141, 0, 'mcl_farming:carrot_1')
_map(141, 1, 'mcl_farming:carrot_2')
_map(141, 2, 'mcl_farming:carrot_3')
_map(141, 3, 'mcl_farming:carrot_4')
_map(141, 4, 'mcl_farming:carrot_5')
_map(141, 5, 'mcl_farming:carrot_6')
_map(141, 6, 'mcl_farming:carrot_7')
_map(141, 7, 'mcl_farming:carrot')
_map(142, 0, 'mcl_farming:potato_1')
_map(142, 1, 'mcl_farming:potato_2')
_map(142, 2, 'mcl_farming:potato_3')
_map(142, 3, 'mcl_farming:potato_4')
_map(142, 4, 'mcl_farming:potato_5')
_map(142, 5, 'mcl_farming:potato_6')
_map(142, 6, 'mcl_farming:potato_7')
_map(142, 7, 'mcl_farming:potato')
_map(143, (0, 1, 5, 8, 9, 13), 'mesecons_button:button_oak_off', 1)
_map(143, (2, 10), 'mesecons_button:button_oak_off', 3)
_map(143, (3, 11), 'mesecons_button:button_oak_off', 2)
_map(143, (4, 12), 'mesecons_button:button_oak_off', 0)
_map_all(145, 'mcl_anvils:anvil')
_map(146, 2, 'mcl_chests:trapped_chest', 2)
_map(146, 3, 'mcl_chests:trapped_chest', 0)
_map(146, 4, 'mcl_chests:trapped_chest', 1)
_map(146, 5, 'mcl_chests:trapped_chest', 3)
_map_all(147, 'mesecons_pressureplates:pressure_plate_stone')
_map_all(148, 'mesecons_pressureplates:pressure_plate_stone')
_map_all(152, 'mesecons_torch:redstoneblock')
_map_all(153, 'mcl_nether:quartz_ore')
_map(155, 0, 'mcl_nether:quartz_block')
_map(155, 1, 'mcl_nether:quartz_chiseled')
_map(155, 2, 'mcl_nether:quartz_pillar')
_map(155, 3, 'mcl_nether:quartz_pillar', 4)
_map(155, 4, 'mcl_nether:quartz_pillar', 12)
_stair(156, 'mcl_stairs:stair_quartzblock')
_map_all(157, 'mcl_minecarts:activator_rail')
_map(159, 0, 'mcl_colorblocks:hardened_clay_white')
_map(159, 1, 'mcl_colorblocks:hardened_clay_orange')
_map(159, 2, 'mcl_colorblocks:hardened_clay_magenta')
_map(159, 3, 'mcl_colorblocks:hardened_clay_light_blue')
_map(159, 4, 'mcl_colorblocks:hardened_clay_yellow')
_map(159, 5, 'mcl_colorblocks:hardened_clay_lime')
_map(159, 6, 'mcl_colorblocks:hardened_clay_pink')
_map(159, 7, 'mcl_colorblocks:hardened_clay_grey')
_map(159, 8, 'mcl_colorblocks:hardened_clay_silver')
_map(159, 9, 'mcl_colorblocks:hardened_clay_cyan')
_map(159, 10, 'mcl_colorblocks:hardened_clay_purple')
_map(159, 11, 'mcl_colorblocks:hardened_clay_blue')
_map(159, 12, 'mcl_colorblocks:hardened_clay_brown')
_map(159, 13, 'mcl_colorblocks:hardened_clay_green')
_map(159, 14, 'mcl_colorblocks:hardened_clay_red')
_map(159, 15, 'mcl_colorblocks:hardened_clay_black')
_map(160, 0, 'mcl_panes:pane_white_flat')
_map(160, 1, 'mcl_panes:pane_orange_flat')
_map(160, 2, 'mcl_panes:pane_magenta_flat')
_map(160, 3, 'mcl_panes:pane_light_blue_flat')
_map(160, 4, 'mcl_panes:pane_yellow_flat')
_map(160, 5, 'mcl_panes:pane_lime_flat')
_map(160, 6, 'mcl_panes:pane_pink_flat')
_map(160, 7, 'mcl_panes:pane_grey_flat')
_map(160, 8, 'mcl_panes:pane_silver_flat')
_map(160, 9, 'mcl_panes:pane_cyan_flat')
_map(160, 10, 'mcl_panes:pane_purple_flat')
_map(160, 11, 'mcl_panes:pane_blue_flat')
_map(160, 12, 'mcl_panes:pane_brown_flat')
_map(160, 13, 'mcl_panes:pane_green_flat')
_map(160, 14, 'mcl_panes:pane_red_flat')
_map(160, 15, 'mcl_panes:pane_black_flat')
_map(161, (0, 8), 'mcl_trees:leaves_acacia')
_map(161, (1, 9), 'mcl_trees:leaves_dark_oak')
_map(161, (4, 12), 'mcl_trees:leaves_acacia', 1)
_map(161, (5, 13), 'mcl_trees:leaves_dark_oak', 1)
_log(162, 0, 'mcl_trees:tree_acacia')
_log(162, 1, 'mcl_trees:tree_dark_oak')
_stair(163, 'mcl_stairs:stair_acacia')
_stair(164, 'mcl_stairs:stair_dark_oak')
_map_all(165, 'mcl_core:slimeblock')
_map_all(166, 'mcl_core:barrier')
_trapdoor(167, 'mcl_doors:iron_trapdoor')
_map(168, 0, 'mcl_ocean:prismarine')
_map(168, 1, 'mcl_ocean:prismarine_brick')
_map(168, 2, 'mcl_ocean:prismarine_dark')
_map_all(169, 'mcl_ocean:sea_lantern')
_map(170, 0, 'mcl_farming:hay_block', 0)
_map(170, 4, 'mcl_farming:hay_block', 12)
_map(170, 8, 'mcl_farming:hay_block', 6)
_map(171, 0, 'mcl_wool:white_carpet')
_map(171, 1, 'mcl_wool:orange_carpet')
_map(171, 2, 'mcl_wool:magenta_carpet')
_map(171, 3, 'mcl_wool:light_blue_carpet')
_map(171, 4, 'mcl_wool:yellow_carpet')
_map(171, 5, 'mcl_wool:lime_carpet')
_map(171, 6, 'mcl_wool:pink_carpet')
_map(171, 7, 'mcl_wool:grey_carpet')
_map(171, 8, 'mcl_wool:silver_carpet')
_map(171, 9, 'mcl_wool:cyan_carpet')
_map(171, 10, 'mcl_wool:purple_carpet')
_map(171, 11, 'mcl_wool:blue_carpet')
_map(171, 12, 'mcl_wool:brown_carpet')
_map(171, 13, 'mcl_wool:green_carpet')
_map(171, 14, 'mcl_wool:red_carpet')
_map(171, 15, 'mcl_wool:black_carpet')
_map_all(172, 'mcl_colorblocks:hardened_clay')
_map_all(173, 'mcl_core:coalblock')
_map_all(174, 'mcl_core:packed_ice')
_map(175, 0, 'mcl_flowers:sunflower')
_map(175, 1, 'mcl_flowers:lilac')
_map(175, 2, 'mcl_flowers:double_grass')
_map(175, 3, 'mcl_flowers:double_fern')
_map(175, 4, 'mcl_flowers:rose_bush')
_map(175, 5, 'mcl_flowers:peony')
_map_all(178, 'mesecons_solarpanel:solar_panel_off')
_map(179, 0, 'mcl_core:redsandstone')
_map(179, 1, 'mcl_core:redsandstonecarved')
_map(179, 2, 'mcl_core:redsandstonesmooth')
_stair(180, 'mcl_stairs:stair_redsandstone')
_map_all(181, 'mcl_core:redsandstone')
_slab(182, 0, 8, 'mcl_stairs:slab_redsandstone')
_gate(183, 'mcl_fences:spruce_fence_gate')
_gate(184, 'mcl_fences:birch_fence_gat')
_gate(185, 'mcl_fences:jungle_fence_gate')
_gate(186, 'mcl_fences:dark_oak_fence_gate')
_gate(187, 'mcl_fences:acacia_fence_gate')
_map_all(188, 'mcl_fences:spruce_fence')
_map_all(189, 'mcl_fences:birch_fence')
_map_all(190, 'mcl_fences:jungle_fence')
_map_all(191, 'mcl_fences:dark_oak_fence')
_map_all(192, 'mcl_fences:acacia_fence')
_door(193, 'mcl_doors:door_spruce')
_door(194, 'mcl_doors:door_birch')
_door(195, 'mcl_doors:door_jungle')
_door(196, 'mcl_doors:door_acacia')
_door(197, 'mcl_doors:door_dark_oak')
_map_all(198, 'mcl_end:end_rod')
_map_all(199, 'mcl_end:chorus_plant')

# Block IDs 200-255
_map_all(200, 'mcl_end:chorus_flower')
_map_all(201, 'mcl_end:purpur_block')
_map_all(202, 'mcl_end:purpur_pillar')
_stair(203, 'mcl_stairs:stair_purpur_block')
_map_all(204, 'mcl_stairs:slab_purpur_block')
_slab(205, 0, 8, 'mcl_stairs:slab_purpur_block')
_map_all(206, 'mcl_end:end_bricks')
_map(207, 0, 'mcl_farming:beetroot_0')
_map(207, 1, 'mcl_farming:beetroot_1')
_map(207, 2, 'mcl_farming:beetroot_2')
_map(207, 3, 'mcl_farming:beetroot')
_map_all(208, 'mcl_core:grass_path')
_map(212, 0, 'mcl_core:frosted_ice_0')
_map(212, 1, 'mcl_core:frosted_ice_1')
_map(212, 2, 'mcl_core:frosted_ice_2')
_map(212, 3, 'mcl_core:frosted_ice_3')
_map_all(213, 'mcl_nether:magma')
_map_all(214, 'mcl_nether:nether_wart_block')
_map_all(215, 'mcl_nether:red_nether_brick')
_map(216, 0, 'mcl_core:bone_block', 0)
_map(216, 4, 'mcl_core:bone_block', 12)
_map(216, 8, 'mcl_core:bone_block', 6)
_map(251, 0, 'mcl_colorblocks:concrete_white')
_map(251, 1, 'mcl_colorblocks:concrete_orange')
_map(251, 2, 'mcl_colorblocks:concrete_magenta')
_map(251, 3, 'mcl_colorblocks:concrete_light_blue')
_map(251, 4, 'mcl_colorblocks:concrete_yellow')
_map(251, 5, 'mcl_colorblocks:concrete_lime')
_map(251, 6, 'mcl_colorblocks:concrete_pink')
_map(251, 7, 'mcl_colorblocks:concrete_grey')
_map(251, 8, 'mcl_colorblocks:concrete_silver')
_map(251, 9, 'mcl_colorblocks:concrete_cyan')
_map(251, 10, 'mcl_colorblocks:concrete_purple')
_map(251, 11, 'mcl_colorblocks:concrete_blue')
_map(251, 12, 'mcl_colorblocks:concrete_brown')
_map(251, 13, 'mcl_colorblocks:concrete_green')
_map(251, 14, 'mcl_colorblocks:concrete_red')
_map(251, 15, 'mcl_colorblocks:concrete_black')
_map(252, 0, 'mcl_colorblocks:concrete_powder_white')
_map(252, 1, 'mcl_colorblocks:concrete_powder_orange')
_map(252, 2, 'mcl_colorblocks:concrete_powder_magenta')
_map(252, 3, 'mcl_colorblocks:concrete_powder_light_blue')
_map(252, 4, 'mcl_colorblocks:concrete_powder_yellow')
_map(252, 5, 'mcl_colorblocks:concrete_powder_lime')
_map(252, 6, 'mcl_colorblocks:concrete_powder_pink')
_map(252, 7, 'mcl_colorblocks:concrete_powder_grey')
_map(252, 8, 'mcl_colorblocks:concrete_powder_silver')
_map(252, 9, 'mcl_colorblocks:concrete_powder_cyan')
_map(252, 10, 'mcl_colorblocks:concrete_powder_purple')
_map(252, 11, 'mcl_colorblocks:concrete_powder_blue')
_map(252, 12, 'mcl_colorblocks:concrete_powder_brown')
_map(252, 13, 'mcl_colorblocks:concrete_powder_green')
_map(252, 14, 'mcl_colorblocks:concrete_powder_red')
_map(252, 15, 'mcl_colorblocks:concrete_powder_black')


def get_block_name(mc_id, mc_data):
    key = (mc_id, mc_data)
    if key in BLOCK_MAP:
        return BLOCK_MAP[key]
    key0 = (mc_id, 0)
    if key0 in BLOCK_MAP:
        return BLOCK_MAP[key0]
    return ('air', 0)


# ── Modern (1.13+) Palette-Based Format ─────────────────────────────────────

MC_NAME_MAP = {
    'minecraft:air': ('air', 0),
    'minecraft:stone': ('mcl_core:stone', 0),
    'minecraft:granite': ('mcl_core:granite', 0),
    'minecraft:polished_granite': ('mcl_core:granite_smooth', 0),
    'minecraft:diorite': ('mcl_core:diorite', 0),
    'minecraft:polished_diorite': ('mcl_core:diorite_smooth', 0),
    'minecraft:andesite': ('mcl_core:andesite', 0),
    'minecraft:polished_andesite': ('mcl_core:andesite_smooth', 0),
    'minecraft:grass_block': ('mcl_core:dirt_with_grass', 0),
    'minecraft:dirt': ('mcl_core:dirt', 0),
    'minecraft:coarse_dirt': ('mcl_core:coarse_dirt', 0),
    'minecraft:podzol': ('mcl_core:podzol', 0),
    'minecraft:cobblestone': ('mcl_core:cobble', 0),
    'minecraft:oak_planks': ('mcl_trees:wood_oak', 0),
    'minecraft:spruce_planks': ('mcl_trees:wood_spruce', 0),
    'minecraft:birch_planks': ('mcl_trees:wood_birch', 0),
    'minecraft:jungle_planks': ('mcl_trees:wood_jungle', 0),
    'minecraft:acacia_planks': ('mcl_trees:wood_acacia', 0),
    'minecraft:dark_oak_planks': ('mcl_trees:wood_dark_oak', 0),
    'minecraft:oak_sapling': ('mcl_trees:sapling_oak', 0),
    'minecraft:spruce_sapling': ('mcl_trees:sapling_spruce', 0),
    'minecraft:birch_sapling': ('mcl_trees:sapling_birch', 0),
    'minecraft:jungle_sapling': ('mcl_trees:sapling_jungle', 0),
    'minecraft:acacia_sapling': ('mcl_trees:sapling_acacia', 0),
    'minecraft:dark_oak_sapling': ('mcl_trees:sapling_dark_oak', 0),
    'minecraft:bedrock': ('mcl_core:bedrock', 0),
    'minecraft:water': ('mcl_core:water_source', 0),
    'minecraft:lava': ('mcl_core:lava_source', 0),
    'minecraft:sand': ('mcl_core:sand', 0),
    'minecraft:red_sand': ('mcl_core:redsand', 0),
    'minecraft:gravel': ('mcl_core:gravel', 0),
    'minecraft:gold_ore': ('mcl_core:stone_with_gold', 0),
    'minecraft:iron_ore': ('mcl_core:stone_with_iron', 0),
    'minecraft:coal_ore': ('mcl_core:stone_with_coal', 0),
    'minecraft:oak_log': ('mcl_trees:tree_oak', 0),
    'minecraft:spruce_log': ('mcl_trees:tree_spruce', 0),
    'minecraft:birch_log': ('mcl_trees:tree_birch', 0),
    'minecraft:jungle_log': ('mcl_trees:tree_jungle', 0),
    'minecraft:acacia_log': ('mcl_trees:tree_acacia', 0),
    'minecraft:dark_oak_log': ('mcl_trees:tree_dark_oak', 0),
    'minecraft:stripped_oak_log': ('mcl_trees:tree_oak', 4),
    'minecraft:stripped_spruce_log': ('mcl_trees:tree_spruce', 4),
    'minecraft:stripped_birch_log': ('mcl_trees:tree_birch', 4),
    'minecraft:stripped_jungle_log': ('mcl_trees:tree_jungle', 4),
    'minecraft:stripped_acacia_log': ('mcl_trees:tree_acacia', 4),
    'minecraft:stripped_dark_oak_log': ('mcl_trees:tree_dark_oak', 4),
    'minecraft:oak_leaves': ('mcl_trees:leaves_oak', 0),
    'minecraft:spruce_leaves': ('mcl_trees:leaves_spruce', 0),
    'minecraft:birch_leaves': ('mcl_trees:leaves_birch', 0),
    'minecraft:jungle_leaves': ('mcl_trees:leaves_jungle', 0),
    'minecraft:acacia_leaves': ('mcl_trees:leaves_acacia', 0),
    'minecraft:dark_oak_leaves': ('mcl_trees:leaves_dark_oak', 0),
    'minecraft:sponge': ('mcl_sponges:sponge', 0),
    'minecraft:wet_sponge': ('mcl_sponges:sponge_wet', 0),
    'minecraft:glass': ('mcl_core:glass', 0),
    'minecraft:lapis_ore': ('mcl_core:stone_with_lapis', 0),
    'minecraft:lapis_block': ('mcl_core:lapisblock', 0),
    'minecraft:sandstone': ('mcl_core:sandstone', 0),
    'minecraft:chiseled_sandstone': ('mcl_core:sandstonecarved', 0),
    'minecraft:cut_sandstone': ('mcl_core:sandstonesmooth', 0),
    'minecraft:note_block': ('mesecons_noteblock:noteblock', 0),
    'minecraft:powered_rail': ('mcl_minecarts:golden_rail', 0),
    'minecraft:detector_rail': ('mcl_minecarts:detector_rail', 0),
    'minecraft:cobweb': ('mcl_core:cobweb', 0),
    'minecraft:grass': ('mcl_flowers:tallgrass', 0),
    'minecraft:fern': ('mcl_flowers:fern', 0),
    'minecraft:dead_bush': ('mcl_core:deadbush', 0),
    'minecraft:white_wool': ('mcl_wool:white', 0),
    'minecraft:orange_wool': ('mcl_wool:orange', 0),
    'minecraft:magenta_wool': ('mcl_wool:magenta', 0),
    'minecraft:light_blue_wool': ('mcl_wool:light_blue', 0),
    'minecraft:yellow_wool': ('mcl_wool:yellow', 0),
    'minecraft:lime_wool': ('mcl_wool:lime', 0),
    'minecraft:pink_wool': ('mcl_wool:pink', 0),
    'minecraft:gray_wool': ('mcl_wool:grey', 0),
    'minecraft:light_gray_wool': ('mcl_wool:silver', 0),
    'minecraft:cyan_wool': ('mcl_wool:cyan', 0),
    'minecraft:purple_wool': ('mcl_wool:purple', 0),
    'minecraft:blue_wool': ('mcl_wool:blue', 0),
    'minecraft:brown_wool': ('mcl_wool:brown', 0),
    'minecraft:green_wool': ('mcl_wool:green', 0),
    'minecraft:red_wool': ('mcl_wool:red', 0),
    'minecraft:black_wool': ('mcl_wool:black', 0),
    'minecraft:dandelion': ('mcl_flowers:dandelion', 0),
    'minecraft:poppy': ('mcl_flowers:poppy', 0),
    'minecraft:blue_orchid': ('mcl_flowers:blue_orchid', 0),
    'minecraft:allium': ('mcl_flowers:allium', 0),
    'minecraft:azure_bluet': ('mcl_flowers:azure_bluet', 0),
    'minecraft:red_tulip': ('mcl_flowers:tulip_red', 0),
    'minecraft:orange_tulip': ('mcl_flowers:tulip_orange', 0),
    'minecraft:white_tulip': ('mcl_flowers:tulip_white', 0),
    'minecraft:pink_tulip': ('mcl_flowers:tulip_pink', 0),
    'minecraft:oxeye_daisy': ('mcl_flowers:oxeye_daisy', 0),
    'minecraft:brown_mushroom': ('mcl_mushrooms:mushroom_brown', 0),
    'minecraft:red_mushroom': ('mcl_mushrooms:mushroom_red', 0),
    'minecraft:gold_block': ('mcl_core:goldblock', 0),
    'minecraft:iron_block': ('mcl_core:ironblock', 0),
    'minecraft:brick_block': ('mcl_core:brick_block', 0),
    'minecraft:bricks': ('mcl_core:brick_block', 0),
    'minecraft:tnt': ('mcl_tnt:tnt', 0),
    'minecraft:bookshelf': ('mcl_books:bookshelf', 0),
    'minecraft:mossy_cobblestone': ('mcl_core:mossycobble', 0),
    'minecraft:obsidian': ('mcl_core:obsidian', 0),
    'minecraft:torch': ('mcl_torches:torch', 1),
    'minecraft:fire': ('mcl_fire:fire', 0),
    'minecraft:spawner': ('mcl_mobspawners:spawner', 0),
    'minecraft:chest': ('mcl_chests:chest', 0),
    'minecraft:redstone_wire': ('mesecons:wire_00000000_off', 0),
    'minecraft:diamond_ore': ('mcl_core:stone_with_diamond', 0),
    'minecraft:diamond_block': ('mcl_core:diamondblock', 0),
    'minecraft:crafting_table': ('mcl_crafting_table:crafting_table', 0),
    'minecraft:farmland': ('mcl_farming:soil', 0),
    'minecraft:furnace': ('mcl_furnaces:furnace', 0),
    'minecraft:ladder': ('mcl_core:ladder', 2),
    'minecraft:rail': ('mcl_minecarts:rail', 0),
    'minecraft:lever': ('mesecons_walllever:wall_lever_off', 0),
    'minecraft:redstone_ore': ('mcl_core:stone_with_redstone', 0),
    'minecraft:ice': ('mcl_core:ice', 0),
    'minecraft:snow_block': ('mcl_core:snowblock', 0),
    'minecraft:cactus': ('mcl_core:cactus', 0),
    'minecraft:clay': ('mcl_core:clay', 0),
    'minecraft:sugar_cane': ('mcl_core:reeds', 0),
    'minecraft:jukebox': ('mcl_jukebox:jukebox', 0),
    'minecraft:oak_fence': ('mcl_fences:oak_fence', 0),
    'minecraft:pumpkin': ('mcl_farming:pumpkin_face', 0),
    'minecraft:netherrack': ('mcl_nether:netherrack', 0),
    'minecraft:soul_sand': ('mcl_nether:soul_sand', 0),
    'minecraft:glowstone': ('mcl_nether:glowstone', 0),
    'minecraft:nether_portal': ('mcl_portals:portal', 0),
    'minecraft:jack_o_lantern': ('mcl_farming:pumpkin_face_light', 0),
    'minecraft:white_stained_glass': ('mcl_core:glass_white', 0),
    'minecraft:orange_stained_glass': ('mcl_core:glass_orange', 0),
    'minecraft:magenta_stained_glass': ('mcl_core:glass_magenta', 0),
    'minecraft:light_blue_stained_glass': ('mcl_core:glass_light_blue', 0),
    'minecraft:yellow_stained_glass': ('mcl_core:glass_yellow', 0),
    'minecraft:lime_stained_glass': ('mcl_core:glass_lime', 0),
    'minecraft:pink_stained_glass': ('mcl_core:glass_pink', 0),
    'minecraft:gray_stained_glass': ('mcl_core:glass_gray', 0),
    'minecraft:light_gray_stained_glass': ('mcl_core:glass_silver', 0),
    'minecraft:cyan_stained_glass': ('mcl_core:glass_cyan', 0),
    'minecraft:purple_stained_glass': ('mcl_core:glass_purple', 0),
    'minecraft:blue_stained_glass': ('mcl_core:glass_blue', 0),
    'minecraft:brown_stained_glass': ('mcl_core:glass_brown', 0),
    'minecraft:green_stained_glass': ('mcl_core:glass_green', 0),
    'minecraft:red_stained_glass': ('mcl_core:glass_red', 0),
    'minecraft:black_stained_glass': ('mcl_core:glass_black', 0),
    'minecraft:iron_bars': ('mcl_panes:bar', 0),
    'minecraft:glass_pane': ('mcl_panes:pane_natural', 0),
    'minecraft:melon': ('mcl_farming:melon', 0),
    'minecraft:vine': ('mcl_core:vine', 0),
    'minecraft:brick_stairs': ('mcl_stairs:stair_brick_block', 0),
    'minecraft:stone_brick_stairs': ('mcl_stairs:stair_stonebrick', 0),
    'minecraft:mycelium': ('mcl_core:mycelium', 0),
    'minecraft:lily_pad': ('mcl_flowers:waterlily', 0),
    'minecraft:nether_bricks': ('mcl_nether:nether_brick', 0),
    'minecraft:nether_brick_fence': ('mcl_fences:nether_brick_fence', 0),
    'minecraft:nether_brick_stairs': ('mcl_stairs:stair_nether_brick', 0),
    'minecraft:end_stone': ('mcl_end:end_stone', 0),
    'minecraft:dragon_egg': ('mcl_end:dragon_egg', 0),
    'minecraft:redstone_lamp': ('mesecons_lightstone:lightstone_off', 0),
    'minecraft:emerald_ore': ('mcl_core:stone_with_emerald', 0),
    'minecraft:emerald_block': ('mcl_core:emeraldblock', 0),
    'minecraft:command_block': ('mesecons_commandblock:commandblock_off', 0),
    'minecraft:beacon': ('mcl_beacons:beacon', 0),
    'minecraft:cobblestone_wall': ('mcl_walls:cobble', 0),
    'minecraft:mossy_cobblestone_wall': ('mcl_walls:mossycobble', 0),
    'minecraft:anvil': ('mcl_anvils:anvil', 0),
    'minecraft:quartz_block': ('mcl_nether:quartz_block', 0),
    'minecraft:chiseled_quartz_block': ('mcl_nether:quartz_chiseled', 0),
    'minecraft:quartz_pillar': ('mcl_nether:quartz_pillar', 0),
    'minecraft:activator_rail': ('mcl_minecarts:activator_rail', 0),
    'minecraft:white_terracotta': ('mcl_colorblocks:hardened_clay_white', 0),
    'minecraft:orange_terracotta': ('mcl_colorblocks:hardened_clay_orange', 0),
    'minecraft:magenta_terracotta': ('mcl_colorblocks:hardened_clay_magenta', 0),
    'minecraft:light_blue_terracotta': ('mcl_colorblocks:hardened_clay_light_blue', 0),
    'minecraft:yellow_terracotta': ('mcl_colorblocks:hardened_clay_yellow', 0),
    'minecraft:lime_terracotta': ('mcl_colorblocks:hardened_clay_lime', 0),
    'minecraft:pink_terracotta': ('mcl_colorblocks:hardened_clay_pink', 0),
    'minecraft:gray_terracotta': ('mcl_colorblocks:hardened_clay_grey', 0),
    'minecraft:light_gray_terracotta': ('mcl_colorblocks:hardened_clay_silver', 0),
    'minecraft:cyan_terracotta': ('mcl_colorblocks:hardened_clay_cyan', 0),
    'minecraft:purple_terracotta': ('mcl_colorblocks:hardened_clay_purple', 0),
    'minecraft:blue_terracotta': ('mcl_colorblocks:hardened_clay_blue', 0),
    'minecraft:brown_terracotta': ('mcl_colorblocks:hardened_clay_brown', 0),
    'minecraft:green_terracotta': ('mcl_colorblocks:hardened_clay_green', 0),
    'minecraft:red_terracotta': ('mcl_colorblocks:hardened_clay_red', 0),
    'minecraft:black_terracotta': ('mcl_colorblocks:hardened_clay_black', 0),
    'minecraft:slime_block': ('mcl_core:slimeblock', 0),
    'minecraft:prismarine': ('mcl_ocean:prismarine', 0),
    'minecraft:prismarine_bricks': ('mcl_ocean:prismarine_brick', 0),
    'minecraft:dark_prismarine': ('mcl_ocean:prismarine_dark', 0),
    'minecraft:sea_lantern': ('mcl_ocean:sea_lantern', 0),
    'minecraft:hay_block': ('mcl_farming:hay_block', 0),
    'minecraft:white_carpet': ('mcl_wool:white_carpet', 0),
    'minecraft:orange_carpet': ('mcl_wool:orange_carpet', 0),
    'minecraft:magenta_carpet': ('mcl_wool:magenta_carpet', 0),
    'minecraft:light_blue_carpet': ('mcl_wool:light_blue_carpet', 0),
    'minecraft:yellow_carpet': ('mcl_wool:yellow_carpet', 0),
    'minecraft:lime_carpet': ('mcl_wool:lime_carpet', 0),
    'minecraft:pink_carpet': ('mcl_wool:pink_carpet', 0),
    'minecraft:gray_carpet': ('mcl_wool:grey_carpet', 0),
    'minecraft:light_gray_carpet': ('mcl_wool:silver_carpet', 0),
    'minecraft:cyan_carpet': ('mcl_wool:cyan_carpet', 0),
    'minecraft:purple_carpet': ('mcl_wool:purple_carpet', 0),
    'minecraft:blue_carpet': ('mcl_wool:blue_carpet', 0),
    'minecraft:brown_carpet': ('mcl_wool:brown_carpet', 0),
    'minecraft:green_carpet': ('mcl_wool:green_carpet', 0),
    'minecraft:red_carpet': ('mcl_wool:red_carpet', 0),
    'minecraft:black_carpet': ('mcl_wool:black_carpet', 0),
    'minecraft:terracotta': ('mcl_colorblocks:hardened_clay', 0),
    'minecraft:coal_block': ('mcl_core:coalblock', 0),
    'minecraft:packed_ice': ('mcl_core:packed_ice', 0),
    'minecraft:sunflower': ('mcl_flowers:sunflower', 0),
    'minecraft:lilac': ('mcl_flowers:lilac', 0),
    'minecraft:peony': ('mcl_flowers:peony', 0),
    'minecraft:rose_bush': ('mcl_flowers:rose_bush', 0),
    'minecraft:nether_wart_block': ('mcl_nether:nether_wart_block', 0),
    'minecraft:red_nether_bricks': ('mcl_nether:red_nether_brick', 0),
    'minecraft:bone_block': ('mcl_core:bone_block', 0),
    'minecraft:end_rod': ('mcl_end:end_rod', 0),
    'minecraft:chorus_plant': ('mcl_end:chorus_plant', 0),
    'minecraft:chorus_flower': ('mcl_end:chorus_flower', 0),
    'minecraft:purpur_block': ('mcl_end:purpur_block', 0),
    'minecraft:purpur_pillar': ('mcl_end:purpur_pillar', 0),
    'minecraft:purpur_stairs': ('mcl_stairs:stair_purpur_block', 0),
    'minecraft:end_stone_bricks': ('mcl_end:end_bricks', 0),
    'minecraft:magma_block': ('mcl_nether:magma', 0),
    'minecraft:red_sandstone': ('mcl_core:redsandstone', 0),
    'minecraft:chiseled_red_sandstone': ('mcl_core:redsandstonecarved', 0),
    'minecraft:cut_red_sandstone': ('mcl_core:redsandstonesmooth', 0),
    'minecraft:white_concrete': ('mcl_colorblocks:concrete_white', 0),
    'minecraft:orange_concrete': ('mcl_colorblocks:concrete_orange', 0),
    'minecraft:magenta_concrete': ('mcl_colorblocks:concrete_magenta', 0),
    'minecraft:light_blue_concrete': ('mcl_colorblocks:concrete_light_blue', 0),
    'minecraft:yellow_concrete': ('mcl_colorblocks:concrete_yellow', 0),
    'minecraft:lime_concrete': ('mcl_colorblocks:concrete_lime', 0),
    'minecraft:pink_concrete': ('mcl_colorblocks:concrete_pink', 0),
    'minecraft:gray_concrete': ('mcl_colorblocks:concrete_grey', 0),
    'minecraft:light_gray_concrete': ('mcl_colorblocks:concrete_silver', 0),
    'minecraft:cyan_concrete': ('mcl_colorblocks:concrete_cyan', 0),
    'minecraft:purple_concrete': ('mcl_colorblocks:concrete_purple', 0),
    'minecraft:blue_concrete': ('mcl_colorblocks:concrete_blue', 0),
    'minecraft:brown_concrete': ('mcl_colorblocks:concrete_brown', 0),
    'minecraft:green_concrete': ('mcl_colorblocks:concrete_green', 0),
    'minecraft:red_concrete': ('mcl_colorblocks:concrete_red', 0),
    'minecraft:black_concrete': ('mcl_colorblocks:concrete_black', 0),
    'minecraft:white_concrete_powder': ('mcl_colorblocks:concrete_powder_white', 0),
    'minecraft:orange_concrete_powder': ('mcl_colorblocks:concrete_powder_orange', 0),
    'minecraft:magenta_concrete_powder': ('mcl_colorblocks:concrete_powder_magenta', 0),
    'minecraft:light_blue_concrete_powder': ('mcl_colorblocks:concrete_powder_light_blue', 0),
    'minecraft:yellow_concrete_powder': ('mcl_colorblocks:concrete_powder_yellow', 0),
    'minecraft:lime_concrete_powder': ('mcl_colorblocks:concrete_powder_lime', 0),
    'minecraft:pink_concrete_powder': ('mcl_colorblocks:concrete_powder_pink', 0),
    'minecraft:gray_concrete_powder': ('mcl_colorblocks:concrete_powder_grey', 0),
    'minecraft:light_gray_concrete_powder': ('mcl_colorblocks:concrete_powder_silver', 0),
    'minecraft:cyan_concrete_powder': ('mcl_colorblocks:concrete_powder_cyan', 0),
    'minecraft:purple_concrete_powder': ('mcl_colorblocks:concrete_powder_purple', 0),
    'minecraft:blue_concrete_powder': ('mcl_colorblocks:concrete_powder_blue', 0),
    'minecraft:brown_concrete_powder': ('mcl_colorblocks:concrete_powder_brown', 0),
    'minecraft:green_concrete_powder': ('mcl_colorblocks:concrete_powder_green', 0),
    'minecraft:red_concrete_powder': ('mcl_colorblocks:concrete_powder_red', 0),
    'minecraft:black_concrete_powder': ('mcl_colorblocks:concrete_powder_black', 0),
    'minecraft:dead_brain_coral': ('mcl_ocean:dead_brain_coral', 0),
    'minecraft:dead_bubble_coral': ('mcl_ocean:dead_bubble_coral', 0),
    'minecraft:dead_fire_coral': ('mcl_ocean:dead_fire_coral', 0),
    'minecraft:dead_horn_coral': ('mcl_ocean:dead_horn_coral', 0),
    'minecraft:dead_tube_coral': ('mcl_ocean:dead_tube_coral', 0),
    'minecraft:dried_kelp_block': ('mcl_ocean:dried_kelp_block', 0),
    'minecraft:barrel': ('mcl_barrels:barrel', 0),
    'minecraft:blast_furnace': ('mcl_blast_furnace:blast_furnace', 0),
    'minecraft:smoker': ('mcl_smoker:smoker', 0),
    'minecraft:grindstone': ('mcl_grindstone:grindstone', 0),
    'minecraft:loom': ('mcl_loom:loom', 0),
    'minecraft:stonecutter': ('mcl_stonecutter:stonecutter', 0),
    'minecraft:cartography_table': ('mcl_cartography_table:cartography_table', 0),
    'minecraft:fletching_table': ('mcl_fletching_table:fletching_table', 0),
    'minecraft:smithing_table': ('mcl_smithing_table:smithing_table', 0),
    'minecraft:composter': ('mcl_composter:composter', 0),
    'minecraft:bell': ('mcl_bell:bell', 0),
    'minecraft:lantern': ('mcl_lanterns:lantern', 0),
    'minecraft:soul_lantern': ('mcl_lanterns:soul_lantern', 0),
    'minecraft:campfire': ('mcl_campfires:campfire', 0),
    'minecraft:soul_campfire': ('mcl_campfires:soul_campfire', 0),
    'minecraft:honey_block': ('mcl_honey:honey_block', 0),
    'minecraft:honeycomb_block': ('mcl_honey:honeycomb_block', 0),
    'minecraft:lodestone': ('mcl_lodestone:lodestone', 0),
    'minecraft:crying_obsidian': ('mcl_core:crying_obsidian', 0),
    'minecraft:blackstone': ('mcl_blackstone:blackstone', 0),
    'minecraft:gilded_blackstone': ('mcl_blackstone:gilded_blackstone', 0),
    'minecraft:chiseled_polished_blackstone': ('mcl_blackstone:chiseled_polished_blackstone', 0),
    'minecraft:polished_blackstone_bricks': ('mcl_blackstone:polished_blackstone_brick', 0),
    'minecraft:cracked_polished_blackstone_bricks': ('mcl_blackstone:cracked_polished_blackstone_brick', 0),
    'minecraft:basalt': ('mcl_blackstone:basalt', 0),
    'minecraft:smooth_basalt': ('mcl_blackstone:smooth_basalt', 0),
    'minecraft:warped_nylium': ('mcl_blackstone:warped_nylium', 0),
    'minecraft:crimson_nylium': ('mcl_blackstone:crimson_nylium', 0),
    'minecraft:shroomlight': ('mcl_blackstone:shroomlight', 0),
    'minecraft:target': ('mcl_target:target', 0),
    'minecraft:netherite_block': ('mcl_netherite:netherite_block', 0),
    'minecraft:ancient_debris': ('mcl_netherite:ancient_debris', 0),
    'minecraft:blue_ice': ('mcl_core:blue_ice', 0),
    'minecraft:chain': ('mcl_chains:chain', 0),
    # Stairs
    'minecraft:oak_stairs': ('mcl_stairs:stair_oak', 1),
    'minecraft:spruce_stairs': ('mcl_stairs:stair_spruce', 1),
    'minecraft:birch_stairs': ('mcl_stairs:stair_birch', 1),
    'minecraft:jungle_stairs': ('mcl_stairs:stair_jungle', 1),
    'minecraft:acacia_stairs': ('mcl_stairs:stair_acacia', 1),
    'minecraft:dark_oak_stairs': ('mcl_stairs:stair_dark_oak', 1),
    'minecraft:cobblestone_stairs': ('mcl_stairs:stair_cobble', 1),
    'minecraft:sandstone_stairs': ('mcl_stairs:stair_sandstone', 1),
    'minecraft:red_sandstone_stairs': ('mcl_stairs:stair_redsandstone', 1),
    'minecraft:stone_stairs': ('mcl_stairs:stair_stone', 1),
    'minecraft:stone_brick_stairs': ('mcl_stairs:stair_stonebrick', 1),
    'minecraft:mossy_stone_brick_stairs': ('mcl_stairs:stair_mossystonebrick', 1),
    'minecraft:granite_stairs': ('mcl_stairs:stair_granite', 1),
    'minecraft:polished_granite_stairs': ('mcl_stairs:stair_granite_smooth', 1),
    'minecraft:diorite_stairs': ('mcl_stairs:stair_diorite', 1),
    'minecraft:polished_diorite_stairs': ('mcl_stairs:stair_diorite_smooth', 1),
    'minecraft:andesite_stairs': ('mcl_stairs:stair_andesite', 1),
    'minecraft:polished_andesite_stairs': ('mcl_stairs:stair_andesite_smooth', 1),
    'minecraft:quartz_stairs': ('mcl_stairs:stair_quartzblock', 1),
    'minecraft:smooth_quartz_stairs': ('mcl_stairs:stair_quartzblock_smooth', 1),
    'minecraft:nether_brick_stairs': ('mcl_stairs:stair_nether_brick', 1),
    'minecraft:red_nether_brick_stairs': ('mcl_stairs:stair_red_nether_brick', 1),
    'minecraft:prismarine_stairs': ('mcl_stairs:stair_prismarine', 1),
    'minecraft:prismarine_brick_stairs': ('mcl_stairs:stair_prismarine_brick', 1),
    'minecraft:dark_prismarine_stairs': ('mcl_stairs:stair_dark_prismarine', 1),
    'minecraft:brick_stairs': ('mcl_stairs:stair_brick_block', 1),
    'minecraft:mossy_cobblestone_stairs': ('mcl_stairs:stair_mossycobble', 1),
    'minecraft:end_stone_brick_stairs': ('mcl_stairs:stair_end_brick', 1),
    'minecraft:purpur_stairs': ('mcl_stairs:stair_purpur_block', 1),
    'minecraft:blackstone_stairs': ('mcl_stairs:stair_blackstone', 1),
    'minecraft:polished_blackstone_stairs': ('mcl_stairs:stair_polished_blackstone', 1),
    'minecraft:polished_blackstone_brick_stairs': ('mcl_stairs:stair_polished_blackstone_brick', 1),
    'minecraft:waxed_cut_copper_stairs': ('mcl_stairs:stair_copper_cut', 1),
    'minecraft:waxed_exposed_cut_copper_stairs': ('mcl_stairs:stair_exposed_cut_copper', 1),
    'minecraft:waxed_weathered_cut_copper_stairs': ('mcl_stairs:stair_weathered_cut_copper', 1),
    'minecraft:waxed_oxidized_cut_copper_stairs': ('mcl_stairs:stair_oxidized_cut_copper', 1),
    # Slabs
    'minecraft:stone_slab': ('mcl_stairs:slab_stone', 0),
    'minecraft:smooth_stone_slab': ('mcl_stairs:slab_stone_smooth', 0),
    'minecraft:cobblestone_slab': ('mcl_stairs:slab_cobble', 0),
    'minecraft:sandstone_slab': ('mcl_stairs:slab_sandstone', 0),
    'minecraft:cut_sandstone_slab': ('mcl_stairs:slab_cut_sandstone', 0),
    'minecraft:red_sandstone_slab': ('mcl_stairs:slab_redsandstone', 0),
    'minecraft:cut_red_sandstone_slab': ('mcl_stairs:slab_cut_redsandstone', 0),
    'minecraft:oak_slab': ('mcl_stairs:slab_oak', 0),
    'minecraft:spruce_slab': ('mcl_stairs:slab_spruce', 0),
    'minecraft:birch_slab': ('mcl_stairs:slab_birch', 0),
    'minecraft:jungle_slab': ('mcl_stairs:slab_jungle', 0),
    'minecraft:acacia_slab': ('mcl_stairs:slab_acacia', 0),
    'minecraft:dark_oak_slab': ('mcl_stairs:slab_dark_oak', 0),
    'minecraft:stone_brick_slab': ('mcl_stairs:slab_stonebrick', 0),
    'minecraft:mossy_stone_brick_slab': ('mcl_stairs:slab_mossystonebrick', 0),
    'minecraft:brick_slab': ('mcl_stairs:slab_brick_block', 0),
    'minecraft:nether_brick_slab': ('mcl_stairs:slab_nether_brick', 0),
    'minecraft:red_nether_brick_slab': ('mcl_stairs:slab_red_nether_brick', 0),
    'minecraft:quartz_slab': ('mcl_stairs:slab_quartzblock', 0),
    'minecraft:smooth_quartz_slab': ('mcl_stairs:slab_quartzblock_smooth', 0),
    'minecraft:purpur_slab': ('mcl_stairs:slab_purpur_block', 0),
    'minecraft:prismarine_slab': ('mcl_stairs:slab_prismarine', 0),
    'minecraft:prismarine_brick_slab': ('mcl_stairs:slab_prismarine_brick', 0),
    'minecraft:dark_prismarine_slab': ('mcl_stairs:slab_dark_prismarine', 0),
    'minecraft:granite_slab': ('mcl_stairs:slab_granite', 0),
    'minecraft:polished_granite_slab': ('mcl_stairs:slab_granite_smooth', 0),
    'minecraft:diorite_slab': ('mcl_stairs:slab_diorite', 0),
    'minecraft:polished_diorite_slab': ('mcl_stairs:slab_diorite_smooth', 0),
    'minecraft:andesite_slab': ('mcl_stairs:slab_andesite', 0),
    'minecraft:polished_andesite_slab': ('mcl_stairs:slab_andesite_smooth', 0),
    'minecraft:end_stone_brick_slab': ('mcl_stairs:slab_end_brick', 0),
    'minecraft:blackstone_slab': ('mcl_stairs:slab_blackstone', 0),
    'minecraft:polished_blackstone_slab': ('mcl_stairs:slab_polished_blackstone', 0),
    'minecraft:polished_blackstone_brick_slab': ('mcl_stairs:slab_polished_blackstone_brick', 0),
    'minecraft:waxed_cut_copper_slab': ('mcl_stairs:slab_copper_cut', 0),
    'minecraft:waxed_exposed_cut_copper_slab': ('mcl_stairs:slab_exposed_cut_copper', 0),
    'minecraft:waxed_weathered_cut_copper_slab': ('mcl_stairs:slab_weathered_cut_copper', 0),
    'minecraft:waxed_oxidized_cut_copper_slab': ('mcl_stairs:slab_oxidized_cut_copper', 0),
    # Fences & Gates
    'minecraft:spruce_fence': ('mcl_fences:spruce_fence', 0),
    'minecraft:birch_fence': ('mcl_fences:birch_fence', 0),
    'minecraft:jungle_fence': ('mcl_fences:jungle_fence', 0),
    'minecraft:acacia_fence': ('mcl_fences:acacia_fence', 0),
    'minecraft:dark_oak_fence': ('mcl_fences:dark_oak_fence', 0),
    'minecraft:nether_brick_fence': ('mcl_fences:nether_brick_fence', 0),
    'minecraft:oak_fence_gate': ('mcl_fences:oak_fence_gate_closed', 0),
    'minecraft:spruce_fence_gate': ('mcl_fences:spruce_fence_gate_closed', 0),
    'minecraft:birch_fence_gate': ('mcl_fences:birch_fence_gate_closed', 0),
    'minecraft:jungle_fence_gate': ('mcl_fences:jungle_fence_gate_closed', 0),
    'minecraft:acacia_fence_gate': ('mcl_fences:acacia_fence_gate_closed', 0),
    'minecraft:dark_oak_fence_gate': ('mcl_fences:dark_oak_fence_gate_closed', 0),
    # Doors
    'minecraft:oak_door': ('mcl_doors:door_oak_b_1', 1),
    'minecraft:spruce_door': ('mcl_doors:door_spruce_b_1', 1),
    'minecraft:birch_door': ('mcl_doors:door_birch_b_1', 1),
    'minecraft:jungle_door': ('mcl_doors:door_jungle_b_1', 1),
    'minecraft:acacia_door': ('mcl_doors:door_acacia_b_1', 1),
    'minecraft:dark_oak_door': ('mcl_doors:door_dark_oak_b_1', 1),
    'minecraft:iron_door': ('mcl_doors:iron_door_b_1', 1),
    # Trapdoors
    'minecraft:oak_trapdoor': ('mcl_doors:trapdoor', 0),
    'minecraft:spruce_trapdoor': ('mcl_doors:spruce_trapdoor', 0),
    'minecraft:birch_trapdoor': ('mcl_doors:birch_trapdoor', 0),
    'minecraft:jungle_trapdoor': ('mcl_doors:jungle_trapdoor', 0),
    'minecraft:acacia_trapdoor': ('mcl_doors:acacia_trapdoor', 0),
    'minecraft:dark_oak_trapdoor': ('mcl_doors:dark_oak_trapdoor', 0),
    'minecraft:iron_trapdoor': ('mcl_doors:iron_trapdoor', 0),
    # Walls
    'minecraft:andesite_wall': ('mcl_walls:andesite', 0),
    'minecraft:diorite_wall': ('mcl_walls:diorite', 0),
    'minecraft:granite_wall': ('mcl_walls:granite', 0),
    'minecraft:sandstone_wall': ('mcl_walls:sandstone', 0),
    'minecraft:red_sandstone_wall': ('mcl_walls:redsandstone', 0),
    'minecraft:stone_brick_wall': ('mcl_walls:stonebrick', 0),
    'minecraft:mossy_stone_brick_wall': ('mcl_walls:mossystonebrick', 0),
    'minecraft:brick_wall': ('mcl_walls:brick_block', 0),
    'minecraft:nether_brick_wall': ('mcl_walls:nether_brick', 0),
    'minecraft:red_nether_brick_wall': ('mcl_walls:red_nether_brick', 0),
    'minecraft:end_stone_brick_wall': ('mcl_walls:end_brick', 0),
    'minecraft:prismarine_wall': ('mcl_walls:prismarine', 0),
    'minecraft:blackstone_wall': ('mcl_walls:blackstone', 0),
    'minecraft:polished_blackstone_wall': ('mcl_walls:polished_blackstone', 0),
    'minecraft:polished_blackstone_brick_wall': ('mcl_walls:polished_blackstone_brick', 0),
    # Stained glass panes
    'minecraft:white_stained_glass_pane': ('mcl_panes:pane_white_flat', 0),
    'minecraft:orange_stained_glass_pane': ('mcl_panes:pane_orange_flat', 0),
    'minecraft:magenta_stained_glass_pane': ('mcl_panes:pane_magenta_flat', 0),
    'minecraft:light_blue_stained_glass_pane': ('mcl_panes:pane_light_blue_flat', 0),
    'minecraft:yellow_stained_glass_pane': ('mcl_panes:pane_yellow_flat', 0),
    'minecraft:lime_stained_glass_pane': ('mcl_panes:pane_lime_flat', 0),
    'minecraft:pink_stained_glass_pane': ('mcl_panes:pane_pink_flat', 0),
    'minecraft:gray_stained_glass_pane': ('mcl_panes:pane_grey_flat', 0),
    'minecraft:light_gray_stained_glass_pane': ('mcl_panes:pane_silver_flat', 0),
    'minecraft:cyan_stained_glass_pane': ('mcl_panes:pane_cyan_flat', 0),
    'minecraft:purple_stained_glass_pane': ('mcl_panes:pane_purple_flat', 0),
    'minecraft:blue_stained_glass_pane': ('mcl_panes:pane_blue_flat', 0),
    'minecraft:brown_stained_glass_pane': ('mcl_panes:pane_brown_flat', 0),
    'minecraft:green_stained_glass_pane': ('mcl_panes:pane_green_flat', 0),
    'minecraft:red_stained_glass_pane': ('mcl_panes:pane_red_flat', 0),
    'minecraft:black_stained_glass_pane': ('mcl_panes:pane_black_flat', 0),
    # Copper
    'minecraft:copper_block': ('mcl_copper:copper_block', 0),
    'minecraft:exposed_copper': ('mcl_copper:exposed_copper', 0),
    'minecraft:weathered_copper': ('mcl_copper:weathered_copper', 0),
    'minecraft:oxidized_copper': ('mcl_copper:oxidized_copper', 0),
    'minecraft:cut_copper': ('mcl_copper:cut_copper', 0),
    'minecraft:exposed_cut_copper': ('mcl_copper:exposed_cut_copper', 0),
    'minecraft:weathered_cut_copper': ('mcl_copper:weathered_cut_copper', 0),
    'minecraft:oxidized_cut_copper': ('mcl_copper:oxidized_cut_copper', 0),
    'minecraft:waxed_copper_block': ('mcl_copper:waxed_copper_block', 0),
    'minecraft:waxed_exposed_copper': ('mcl_copper:waxed_exposed_copper', 0),
    'minecraft:waxed_weathered_copper': ('mcl_copper:waxed_weathered_copper', 0),
    'minecraft:waxed_oxidized_copper': ('mcl_copper:waxed_oxidized_copper', 0),
    'minecraft:waxed_cut_copper': ('mcl_copper:waxed_cut_copper', 0),
    'minecraft:waxed_exposed_cut_copper': ('mcl_copper:waxed_exposed_cut_copper', 0),
    'minecraft:waxed_weathered_cut_copper': ('mcl_copper:waxed_weathered_cut_copper', 0),
    'minecraft:waxed_oxidized_cut_copper': ('mcl_copper:waxed_oxidized_cut_copper', 0),
    # Misc blocks from schematic
    'minecraft:mossy_stone_bricks': ('mcl_core:stonebrickmossy', 0),
    'minecraft:cracked_stone_bricks': ('mcl_core:stonebrickcracked', 0),
    'minecraft:chiseled_stone_bricks': ('mcl_core:stonebrickcarved', 0),
    'minecraft:chiseled_nether_bricks': ('mcl_nether:chiseled_nether_bricks', 0),
    'minecraft:cracked_nether_bricks': ('mcl_nether:cracked_nether_bricks', 0),
    'minecraft:chiseled_polished_blackstone': ('mcl_blackstone:chiseled_polished_blackstone', 0),
    'minecraft:cracked_polished_blackstone_bricks': ('mcl_blackstone:cracked_polished_blackstone_brick', 0),
    'minecraft:smooth_stone': ('mcl_core:stone_smooth', 0),
    'minecraft:smooth_sandstone': ('mcl_core:sandstonesmooth', 0),
    'minecraft:smooth_red_sandstone': ('mcl_core:redsandstonesmooth', 0),
    'minecraft:smooth_quartz': ('mcl_nether:quartz_block_smooth', 0),
    'minecraft:smooth_basalt': ('mcl_blackstone:smooth_basalt', 0),
    'minecraft:calcite': ('mcl_core:calcite', 0),
    'minecraft:amethyst_block': ('mcl_amethyst:amethyst_block', 0),
    'minecraft:budding_amethyst': ('mcl_amethyst:budding_amethyst', 0),
    'minecraft:tuff': ('mcl_core:tuff', 0),
    'minecraft:dripstone_block': ('mcl_core:dripstone_block', 0),
    'minecraft:pointed_dripstone': ('mcl_core:pointed_dripstone', 0),
    'minecraft:raw_iron_block': ('mcl_core:raw_iron_block', 0),
    'minecraft:raw_copper_block': ('mcl_core:raw_copper_block', 0),
    'minecraft:raw_gold_block': ('mcl_core:raw_gold_block', 0),
    'minecraft:deepslate': ('mcl_deepslate:deepslate', 0),
    'minecraft:cobbled_deepslate': ('mcl_deepslate:cobbled_deepslate', 0),
    'minecraft:polished_deepslate': ('mcl_deepslate:polished_deepslate', 0),
    'minecraft:deepslate_bricks': ('mcl_deepslate:deepslate_bricks', 0),
    'minecraft:cracked_deepslate_bricks': ('mcl_deepslate:cracked_deepslate_bricks', 0),
    'minecraft:deepslate_tiles': ('mcl_deepslate:deepslate_tiles', 0),
    'minecraft:cracked_deepslate_tiles': ('mcl_deepslate:cracked_deepslate_tiles', 0),
    'minecraft:chiseled_deepslate': ('mcl_deepslate:chiseled_deepslate', 0),
    'minecraft:reinforced_deepslate': ('mcl_deepslate:reinforced_deepslate', 0),
    'minecraft:mud': ('mcl_mud:mud', 0),
    'minecraft:packed_mud': ('mcl_mud:packed_mud', 0),
    'minecraft:mud_bricks': ('mcl_mud:mud_bricks', 0),
    'minecraft:mangrove_planks': ('mcl_trees:wood_mangrove', 0),
    'minecraft:mangrove_log': ('mcl_trees:tree_mangrove', 0),
    'minecraft:mangrove_leaves': ('mcl_trees:leaves_mangrove', 0),
    'minecraft:mangrove_roots': ('mcl_trees:mangrove_roots', 0),
    'minecraft:muddy_mangrove_roots': ('mcl_trees:muddy_mangrove_roots', 0),
    'minecraft:sculk': ('mcl_sculk:sculk', 0),
    'minecraft:sculk_catalyst': ('mcl_sculk:sculk_catalyst', 0),
    'minecraft:sculk_shrieker': ('mcl_sculk:sculk_shrieker', 0),
    'minecraft:sculk_sensor': ('mcl_sculk:sculk_sensor', 0),
    'minecraft:calibrated_sculk_sensor': ('mcl_sculk:calibrated_sculk_sensor', 0),
    'mekanism:block_osmium': ('mcl_core:stone', 0),
    'mekanism:block_copper': ('mcl_copper:copper_block', 0),
    'mekanism:block_tin': ('mcl_core:stone', 0),
    'mekanism:block_lead': ('mcl_core:stone', 0),
    'mekanism:block_uranium': ('mcl_core:stone', 0),
    'mekanism:basic_energy_cube': ('mcl_core:stone', 0),
    'mekanism:elite_energy_cube': ('mcl_core:stone', 0),
    'mekanism:ultimate_energy_cube': ('mcl_core:stone', 0),
    'mekanism:basic_induction_cell': ('mcl_core:stone', 0),
    'mekanism:advanced_induction_cell': ('mcl_core:stone', 0),
    'mekanism:elite_induction_cell': ('mcl_core:stone', 0),
    'mekanism:ultimate_induction_cell': ('mcl_core:stone', 0),
    'mekanism:basic_induction_provider': ('mcl_core:stone', 0),
    'mekanism:advanced_induction_provider': ('mcl_core:stone', 0),
    'mekanism:elite_induction_provider': ('mcl_core:stone', 0),
    'mekanism:ultimate_induction_provider': ('mcl_core:stone', 0),
    'mekanism:induction_casing': ('mcl_core:stone', 0),
    'mekanism:induction_port': ('mcl_core:stone', 0),
    'mekanism:supercharged_coil': ('mcl_core:stone', 0),
    'mekanism:pressurized_reaction_chamber': ('mcl_core:stone', 0),
    'mekanism:creative_energy_cube': ('mcl_core:stone', 0),
    'mekanism:industrial_alarm': ('mcl_core:stone', 0),
    'mekanism:teleporter_frame': ('mcl_core:stone', 0),
    'create:railway_casing': ('mcl_core:cobble', 0),
}

# Facing direction → Luanti param2 (facedir) mappings
_FACING_TO_PARAM2 = {
    'north': 0, 'south': 2, 'east': 1, 'west': 3, 'up': 20, 'down': 22,
}
_AXIS_TO_PARAM2 = {
    'y': 0, 'z': 12, 'x': 4,
}


def parse_block_state(state):
    """Parse a block state string into (base_name, props_dict)."""
    if '[' not in state:
        return state, {}
    name, rest = state.split('[', 1)
    rest = rest.rstrip(']')
    props = {}
    for part in rest.split(','):
        if '=' in part:
            k, v = part.split('=', 1)
            props[k] = v
    return name, props


def get_block_name_modern(state):
    """Map a modern MC 1.13+ block state string to Luanti (name, param2)."""
    name, props = parse_block_state(state)

    # Look up base name
    entry = MC_NAME_MAP.get(name)
    if entry is None:
        return ('air', 0)

    luanti_name, param2 = entry

    if not props:
        return (luanti_name, param2)

    # Adjust param2 based on properties for common directional blocks
    facing = props.get('facing')
    half = props.get('half')
    axis = props.get('axis')
    shape = props.get('shape')
    type_val = props.get('type')

    # Stairs
    if 'stair' in name:
        if facing:
            param2 = _FACING_TO_PARAM2.get(facing, param2)
        if half == 'top':
            # Flip upside-down: add 20 (10 in facedir 6-bit scheme)
            if param2 < 4:
                param2 += 20
            else:
                param2 += 22

    # Slabs
    if 'slab' in name or name.endswith('_slab'):
        if type_val == 'top' or half == 'top':
            param2 = 22

    # Logs / Pillars
    if 'log' in name or 'pillar' in name or 'hyphae' in name or 'stem' in name:
        if axis:
            param2 = _AXIS_TO_PARAM2.get(axis, param2)

    # Terracotta / glazed terracotta
    if 'glazed_terracotta' in name and facing:
        param2 = _FACING_TO_PARAM2.get(facing, param2)

    return (luanti_name, param2)


# ── Main ────────────────────────────────────────────────────────────────────

def convert(input_path, output_path):
    with gzip.open(input_path, 'rb') as f:
        raw = f.read()

    nbt = NBT(raw)
    tag_type = nbt.read_byte()
    assert tag_type == TAG_COMPOUND, f"Expected Compound root, got {tag_type}"
    nbt.read_string()
    schematic = nbt.parse_compound()

    width = schematic.get('Width', 0)
    height = schematic.get('Height', 0)
    length = schematic.get('Length', 0)

    print(f"Schematic: {width} x {height} x {length}")

    if width < 1 or height < 1 or length < 1:
        print("error: invalid schematic dimensions", file=sys.stderr)
        sys.exit(1)

    # Detect format: old (Blocks + Data) or new (BlockData + Palette)
    palette = schematic.get('Palette')
    if palette is not None:
        is_modern = True
    else:
        is_modern = False

    expected = width * height * length

    if is_modern:
        block_data = schematic.get('BlockData', b'')

        # Build palette index → name mapping (reverse of Palette compound)
        idx_to_name = {}
        for state_name, idx in palette.items():
            idx_to_name[idx] = state_name

        # Read palette indices using VarInt encoding
        pal_indices = []
        pos = 0
        while pos < len(block_data) and len(pal_indices) < expected:
            val = 0
            shift = 0
            while True:
                byte = block_data[pos]
                pos += 1
                val |= (byte & 0x7F) << shift
                shift += 7
                if not (byte & 0x80):
                    break
            pal_indices.append(val)

        if len(pal_indices) != expected:
            print(f"error: expected {expected} palette indices, got {len(pal_indices)}",
                  file=sys.stderr)
            sys.exit(1)

        # Pre-cache palette index → Luanti mapping
        pal_cache = []
        unmapped_base = set()
        for i in range(len(idx_to_name)):
            state_name = idx_to_name.get(i, 'minecraft:air')
            name, param2 = get_block_name_modern(state_name)
            if name == 'air' and state_name != 'minecraft:air':
                unmapped_base.add(state_name.split('[')[0])
            pal_cache.append((name, param2))

        if unmapped_base:
            names = sorted(unmapped_base)
            if len(names) > 10:
                print(f"warning: {len(unmapped_base)} unmapped block types " +
                      f"(e.g. {', '.join(names[:5])}, ...)")
            else:
                print(f"warning: {len(unmapped_base)} unmapped block types: {', '.join(names)}")

        nodes = [pal_cache[i] for i in pal_indices]
    else:
        # Old format (Blocks + Data + optional BlockAdd)
        blocks_raw = schematic.get('Blocks', b'')
        data_raw = schematic.get('Data', b'')
        block_add = schematic.get('BlockAdd', [])

        if len(blocks_raw) != expected:
            print(f"error: Blocks array size {len(blocks_raw)} != {expected}", file=sys.stderr)
            sys.exit(1)

        full_ids = bytearray(len(blocks_raw))
        for i in range(len(blocks_raw)):
            bid = blocks_raw[i]
            if i < len(block_add) * 32:
                word_idx = i // 32
                bit_idx = i % 32
                if block_add[word_idx] & (1 << bit_idx):
                    bid += 256
            full_ids[i] = bid

        if len(data_raw) < expected:
            data_raw = data_raw + b'\x00' * (expected - len(data_raw))

        nodes = []
        unmapped = set()
        idx = 0
        for y in range(height):
            for z in range(length):
                for x in range(width):
                    bid = full_ids[idx]
                    data_val = data_raw[idx]
                    name, param2 = get_block_name(bid, data_val)
                    if name == 'air' and bid != 0:
                        unmapped.add(bid)
                    nodes.append((name, param2))
                    idx += 1

        if unmapped:
            ids_str = ', '.join(str(b) for b in sorted(unmapped))
            print(f"warning: {len(unmapped)} unmapped block IDs: {ids_str}")

    write_mts(output_path, width, height, length, nodes)
    print(f"Wrote {output_path} ({len(nodes)} nodes)")


def main():
    parser = argparse.ArgumentParser(
        description="Convert Minecraft .schematic files to Luanti .mts format")
    parser.add_argument('input', help='Input .schematic file')
    parser.add_argument('output', help='Output .mts file')
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"error: input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    convert(args.input, args.output)


if __name__ == '__main__':
    main()
