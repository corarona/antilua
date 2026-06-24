# Mapart — Image-to-MTS Schematic Converter

## Problem

Convert any PNG image into a flat MTS schematic (1-block high) using Minecraft-adjacent block colors, so players can build pixel-art "mapart" in the world. Needs to read PNG files from disk, match pixel colors to the nearest available block, and produce a loadable/placeable schematic.

## Design

### C++ Bindings (3 new functions)

All registered in `ModApiClient::InitializeClient()` alongside existing `read_file`, `read_schematic`, etc.

| Function | Signature | Description |
|----------|-----------|-------------|
| `decode_image` | `(png_bytes: string) -> {width, height, data}` | Decodes PNG via Irrlicht's `createImageFromFile()`. Returns RGBA byte string (4 bytes/pixel, row-major). Returns `nil, error` on failure. |
| `write_file` | `(path: string, data: string) -> bool` | Writes data to disk. Path traversal denied (same guard as `read_file`). Returns `nil, error` on failure. |
| `list_dir` | `(path: string) -> {string,...}` | Returns array of filenames in directory. Non-recursive. Returns `nil, error` on failure. |

**`decode_image` implementation** — mirrors `imagesource.cpp` PNG loader pattern:
1. `createMemoryReadFile()` from input bytes
2. `RenderingEngine::get_video_driver()->createImageFromFile(memfile)`
3. Lock image, iterate pixels, pack into flat RGBA byte string
4. Handle both `ECF_A8R8G8B8` and `ECF_R8G8B8` formats

### New Mod: `clientmods/ANTILUA/mapart/`

```
clientmods/ANTILUA/mapart/
├── mod.conf          # depends = wasplib, nlist, schembuilder
├── colors.json       # copied from mineclonia mcl_maps
└── init.lua          # palette, matching, formspec, commands
```

### Palette

On mod load, parse `colors.json` into a flat `palette[]` table. Each entry: `{name, param2, r, g, b, a?}`.

| colors.json format | Palette expansion |
|---|---|
| `[r, g, b]` | One entry, param2=0 |
| `[r, g, b, a, ...]` | One entry with alpha |
| `[[r,g,b], [r,g,b], ...]` | One entry per sub-array, param2 = index-1 |

Filter palette with `nlist.get("mapart_exclude")`: remove any entry whose `name` matches.

### Color Matching Algorithm

For each output pixel:
1. Get `(r, g, b)` from image data
2. If alpha < 128 → skip (leave as air)
3. If gamma correction enabled → linearize RGB values (sRGB → linear)
4. Find palette entry minimizing: `(r-R)² + (g-G)² + (b-B)²`
5. Return `(name, param2)` for schematic

**Dithering** (Floyd-Steinberg, optional):
- Applied per-pixel before color matching
- Quantization error distributed to neighbors: right 7/16, down-left 3/16, down 5/16, down-right 1/16
- Error accumulated in floating-point accumulators per channel

### Schematic Generation

Flat 1-block-high schematic (`size.y = 1`):
```
schem = {
  size = {x = width, y = 1, z = height},
  data = {}
}
for z = 0, height-1:
  for x = 0, width-1:
    pixel = source[ (z*width + x)*4 + offset ]
    if pixel.a >= 128:
      best = find_closest(pixel.r, pixel.g, pixel.b)
      append to schem.data
```

### Schembuilder Integration

New **Mapart** tab added to the schembuilder formspec:

```
[Load] [Save] [Mapart] [Preview] [Place]
+------------------------------------------+
| Dir: [~/antilua_mapart/]        [Refresh]|
+------------------------------------------+
| ○ castle.png                              |
| ○ logo.png                                |
| ○ photo.png                               |
| (click selects, shows preview)            |
+------------------------------------------+
| [Preview: selected PNG (scaled to fit)]    |
|                                           |
+------------------------------------------+
| Size: W:[128] H:[128]                     |
| ☐ Dithering  ☐ Gamma correction          |
| [Convert to MTS]                     Done |
+------------------------------------------+
```

**Preview mechanism:** After selection, the PNG is decoded, resized to fit the formspec area, re-encoded as PNG (`core.encode_png`), base64-encoded, and passed to a formspec `image` element via `[png:BASE64`.

**Conversion flow:**
1. Click "Convert to MTS"
2. Read file → decode → resize → match → serialize
3. MTS saved to `<schematics_dir>/<name>.mts`
4. Schematic loaded into schembuilder's internal list
5. Status shows "Done" with file path
6. User switches to Preview/Place tabs via existing schembuilder features

### Chat Command

```
/mapart <path> [width] [height] [--dither] [--gamma]
```

Quick CLI path without the formspec. Example: `/mapart ~/logo.png 64 64 --dither`.

Output MTS goes to `~/antilua_schematics/<basename>.mts` and is loaded into schembuilder.

### nlist Integration

- `nlist.get("mapart_exclude")` filters the block palette
- Use `/nla mapart_exclude mcl_core:water_source` to exclude unwanted nodes from color matching

### Files Changed

| File | Change |
|------|--------|
| `src/script/lua_api/l_client.h` | Declare `l_decode_image`, `l_write_file`, `l_list_dir` |
| `src/script/lua_api/l_client.cpp` | Implement + register 3 new functions |
| `clientmods/ANTILUA/mapart/mod.conf` | New file |
| `clientmods/ANTILUA/mapart/colors.json` | New file (from `games/mineclonia/mods/ITEMS/mcl_maps/`) |
| `clientmods/ANTILUA/mapart/init.lua` | New file (main implementation) |
| `clientmods/ANTILUA/schembuilder/init.lua` | Add Mapart tab, integrate with schembuilder list |
| `clientmods/al_test/test_mapart.lua` | New test file |

### Tests

1. `decode_image roundtrip` — encode a test pattern, decode, compare pixels
2. `decode_image invalid data returns nil` — pass garbage bytes
3. `write_file roundtrip` — write data, read back, verify
4. `write_file path traversal denied` — ".." in path returns nil
5. `list_dir returns files` — list a known directory, check expected files
6. `palette load` — colors.json parses correctly, all formats handled
7. `color match exact` — known color matches correct block
8. `color match nearest` — off-color input finds closest palette entry
9. `color match with nlist exclude` — excluded node is not returned
10. `schematic generation` — 2x2 test image produces correct MTS data
11. `gamma correction` — gamma toggle changes match result
12. `dithering` — dithering toggle changes which nodes are selected
