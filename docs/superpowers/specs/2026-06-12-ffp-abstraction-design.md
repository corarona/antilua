# FFP Compatibility Code Abstraction

**Date:** 2026-06-12
**Branch:** `opengl-14-compat`
**Goal:** Minimize future merge conflicts with upstream Luanti by abstracting FFP (fixed-function pipeline) compatibility code into separate files.

## Current State

The opengl-14-compat branch modified 40 files (1946 insertions, 167 deletions) to restore OpenGL 1.4 FFP support. FFP code is inlined throughout the Luanti client source using `if/else` branching:

```cpp
if (m_enable_shaders) {
    // shader path (upstream code)
} else {
    // FFP path (our code)
}
```

This creates merge conflicts whenever upstream changes the code around these branches.

## Strategy

Move **all FFP-specific code** to `src/client/ffp/` — new files that upstream doesn't touch. Existing files get **predictable, minimal changes**: add `#include`, replace inline `if/else` with single function calls, remove `m_enable_shaders` member fields.

**Key principle:** Restore upstream function names wherever they were renamed (e.g., `applyMaterialOptionsWithShaders` reverts to `applyMaterialOptions`). The shader path uses the original name; the FFP path calls free functions from `ffp/`.

## Architecture

### New files in `src/client/ffp/`

All new code goes here. 5 source files (5 `.h` + 5 `.cpp`).

#### `ffp_settings.h/cpp`

Single accessor for the `enable_shaders` setting, replacing `g_settings->getBool("enable_shaders")` scattered across 15 files.

```cpp
// Returns true when shaders are enabled (FFP mode is off)
bool ffp_isEnabled();
```

#### `ffp_material.h/cpp`

Centralizes FFP material type selection.

```cpp
// Maps TileLayer material to basic EMT type (EMT_SOLID,
// EMT_TRANSPARENT_ALPHA_CHANNEL, etc.). This is the FFP equivalent
// of TileLayer::applyMaterialOptions(material, layer) — but as a
// free function so tile.cpp doesn't need an FFP variant.
void ffp_applyTileMaterial(video::SMaterial &material, const TileLayer &layer);

// Entity material type for FFP path
video::E_MATERIAL_TYPE ffp_getEntityMaterial(bool use_texture_alpha);
```

#### `ffp_light.h/cpp`

FFP vertex color operations. FFP can't use shader `ColorParam` uniforms, so it updates vertex colors directly on the CPU.

```cpp
// Day/night color blending (moved from mapblock_mesh.h)
void ffp_blendDayNight(video::SColor *result, const video::SColor &src, u32 daynight_ratio);
video::SColorf ffp_getSunlightColor(u32 daynight_ratio);

// Mesh colorization with normal-based shading (moved from mesh.cpp FFP overload)
void ffp_colorizeMeshBuffer(scene::IMeshBuffer *buf, const video::SColor &color);
void ffp_setMeshColor(scene::IMesh *mesh, const video::SColor &color);
```

Note: `final_color_blend` (used by `mapblock_mesh.cpp`, `content_cao.cpp`, `game.cpp`, and `clientenvironment.cpp` in both shader and FFP modes) moves here and is renamed to `ffp_blendDayNight`. **All callers** update to the new name and include, since the function is a general color utility (not FFP-specific). The original declaration is removed from `mapblock_mesh.h`.

#### `ffp_mapblock.h/cpp`

Encapsulates the MapBlock day/night vertex color animation — the most complex FFP feature (~40 lines across constructor + animate). Encapsulates storage and logic in a helper class.

```cpp
class FFPMapBlockDayNightAnimator {
public:
    FFPMapBlockDayNightAnimator();

    // Called during MapBlockMesh construction for each mesh buffer.
    // Extracts original vertex colors and sunlight diffs.
    void addLayer(const MeshCollector &collector, const TileSpec &tile,
                  u8 layer, u32 mesh_index);

    // Called from MapBlockMesh::animate(). Updates vertex colors
    // based on current daynight_ratio. Returns true if changed.
    bool animate(std::vector<scene::SMesh *> &meshes, u32 daynight_ratio);

    bool hasAnimation() const { return !m_daynight_diffs.empty(); }

private:
    std::map<std::pair<u8, u32>, std::map<u32, video::SColor>> m_daynight_diffs;
    u32 m_last_daynight_ratio = (u32)-1;
};
```

#### `ffp_render.h/cpp`

Centralizes FFP gating of rendering features.

```cpp
// Driver preference order: when FFP, prefer EDT_OPENGL over EDT_OPENGL3
std::vector<video::E_DRIVER_TYPE> ffp_getDriverOrder();

// VBOs disabled in FFP mode (client-side vertex arrays required)
bool ffp_shouldEnableVBO();
```

### Existing file changes

| File | Change | Conflict risk before/after |
|------|--------|---------------------------|
| `tile.h/cpp` | **Reverted to upstream** — FFP `applyMaterialOptions(material)` removed, `applyMaterialOptionsWithShaders` renamed back to original `applyMaterialOptions(material, layer)` | High → None |
| `mapblock_mesh.h/cpp` | Remove `m_enable_shaders`, `m_last_daynight_ratio`, `m_daynight_diffs`, `final_color_blend`, `get_sunlight_color`. Add `unique_ptr<FFPMapBlockDayNightAnimator>`. Constructor: inline loop → `addLayer()`. Animate: inline update → `animate()`. | High → Low |
| `content_cao.h/cpp` | Remove `m_material_type_param`, `m_enable_shaders`. Material branch → `ffp_getEntityMaterial()`. `setNodeLight()` FFP branch → `ffp_setMeshColor()`. `updateLight()` FFP branch → `ffp_blendDayNight()`. | High → Low |
| `wieldmesh.h/cpp` | Remove `m_enable_shaders`. `setColor()` FFP branch → `ffp_colorizeMeshBuffer()`. `changeToMesh()` FFP branch → constant hint. `setItem()` FFP branch → `ffp_isEnabled()`. | Medium → Low |
| `clouds.h/cpp` | Remove `m_enable_shaders`. Material type branch → direct `EMT_TRANSPARENT_ALPHA_CHANNEL`. ColorParam guard → direct vertex color. | Medium → Low |
| `sky.h/cpp` | Remove `m_enable_shaders`. Star material → direct EMT. ColorParam guard → `ffp_setMeshBufferColor()`. `updateStars()` hint guard → remove (no-op for FFP). | Medium → Low |
| `hud.cpp` | Replace `enable_shaders` local → use `ffp_isEnabled()` or direct constants. | Low |
| `minimap.h/cpp` | Remove `m_enable_shaders`. Material type branch → direct EMT constant. | Low |
| `shader.cpp` | Keep existing pattern (early returns are already minimal). | Low |
| `renderingengine.cpp` | Driver ordering if/else → `ffp_getDriverOrder()`. VBO guard → `ffp_shouldEnableVBO()`. | Medium |
| `render/plain.cpp` | Replace `enable_shaders && enable_post_processing` with `ffp_isEnabled()` calls. | Low |
| `mesh.h/cpp` | Remove FFP `colorizeMeshBuffer(buf, const SColor*)` overload. | Low |
| `mesh_generator_thread.h/cpp` | Replace `m_cache_enable_shaders` with `ffp_isEnabled()` in constructor. | Low |
| `environment.h/cpp` | Remove unused `m_cache_enable_shaders` field. | Low |

Files **unchanged** from current diff:
- `defaultsettings.cpp` — settings defaults are not merge-conflict-prone
- `content_mapblock.cpp/h` — `enable_mesh_cache` is a general optimization, not FFP-specific
- `unittest/test_content_mapblock.cpp` — test change is trivial
- `builtin/` — Lua files have minimal merge conflict risk
- `irr/` — deferred to step 2

### Summary

- **New files:** 5 headers + 5 implementations in `src/client/ffp/`
- **Changed existing files:** ~15 (from current 40)
- **Reverted existing files:** `tile.h/cpp` fully reverted
- **Merge conflict risk:** Each existing file change is now a simple addition (include + call) — upstream changes create trivial merge resolutions instead of branch-inside-branch conflicts.

### Out of scope (step 2)

Irrlicht driver changes (`irr/src/COpenGLDriver.h/cpp`, `COpenGLMaterialRenderer.h`, `CIrrDeviceSDL.cpp`, `IVideoDriver.h`). These are in a fork that doesn't merge upstream often, and the changes are self-contained.

### Future removal

If FFP support is eventually dropped, removing the abstraction is trivial:
1. Delete `src/client/ffp/`
2. Remove the `#include` lines and function calls from existing files
3. The upstream code path is untouched
