# FFP Compatibility Code Abstraction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all FFP-specific code from Luanti `src/` into new `src/client/ffp/` files to minimize upstream merge conflicts.

**Architecture:** 5 new files in `src/client/ffp/` (settings, material, light, mapblock, render) + revert `tile.h/cpp` to upstream + update ~15 existing callers to use new APIs. Phase 1 creates infrastructure, Phase 2 migrates callers, Phase 3 restores upstream names.

**Tech Stack:** C++17, Luanti engine, IrrlichtMt fork

---

### Task 1: Create `ffp_settings.h/cpp`

**Files:**
- Create: `src/client/ffp/ffp_settings.h`
- Create: `src/client/ffp/ffp_settings.cpp`

- [ ] **Step 1: Create `ffp_settings.h`**

```cpp
#pragma once

bool ffp_isEnabled();
```

- [ ] **Step 2: Create `ffp_settings.cpp`**

```cpp
#include "ffp_settings.h"
#include "settings.h"

bool ffp_isEnabled()
{
	return g_settings->getBool("enable_shaders");
}
```

---

### Task 2: Create `ffp_material.h/cpp`

**Files:**
- Create: `src/client/ffp/ffp_material.h`
- Create: `src/client/ffp/ffp_material.cpp`

- [ ] **Step 1: Create `ffp_material.h`**

```cpp
#pragma once

#include "SMaterial.h"

struct TileLayer;

// Apply FFP-compatible material from a tile layer.
// Sets MaterialType to a basic FFP type based on the layer's material_type.
void ffp_applyTileMaterial(video::SMaterial &material, const TileLayer &layer);

// Get FFP material type for entity rendering.
struct FFPEntityMaterial {
	video::E_MATERIAL_TYPE type;
	f32 param = 0.0f;
};
FFPEntityMaterial ffp_getEntityMaterial(bool use_texture_alpha);
```

- [ ] **Step 2: Create `ffp_material.cpp`**

```cpp
#include "ffp_material.h"
#include "tile.h"

void ffp_applyTileMaterial(video::SMaterial &material, const TileLayer &layer)
{
	if (!layer.texture)
		return;
	material.setTexture(0, layer.texture);
	material.BackfaceCulling = (layer.material_flags & MATERIAL_FLAG_BACKFACE_CULLING) != 0;
	material.setTexture(1, nullptr);

	switch (layer.material_type) {
	case TILE_MATERIAL_BASIC:
	case TILE_MATERIAL_WAVING_LEAVES:
	case TILE_MATERIAL_WAVING_PLANTS:
	case TILE_MATERIAL_WAVING_LIQUID_BASIC:
	case TILE_MATERIAL_LIQUID_OPAQUE:
	case TILE_MATERIAL_WAVING_LIQUID_OPAQUE:
		material.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL_REF;
		break;
	case TILE_MATERIAL_OPAQUE:
	case TILE_MATERIAL_PLAIN:
		material.MaterialType = video::EMT_SOLID;
		break;
	case TILE_MATERIAL_ALPHA:
	case TILE_MATERIAL_LIQUID_TRANSPARENT:
	case TILE_MATERIAL_WAVING_LIQUID_TRANSPARENT:
	case TILE_MATERIAL_PLAIN_ALPHA:
		material.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL;
		break;
	default:
		material.MaterialType = video::EMT_SOLID;
		break;
	}

	if (!(layer.material_flags & MATERIAL_FLAG_TILEABLE_HORIZONTAL))
		material.TextureLayers[0].TextureWrapU = video::ETC_CLAMP_TO_EDGE;
	if (!(layer.material_flags & MATERIAL_FLAG_TILEABLE_VERTICAL))
		material.TextureLayers[0].TextureWrapV = video::ETC_CLAMP_TO_EDGE;
}

FFPEntityMaterial ffp_getEntityMaterial(bool use_texture_alpha)
{
	if (use_texture_alpha)
		return {video::EMT_TRANSPARENT_ALPHA_CHANNEL, 1.0f / 256.f};
	return {video::EMT_TRANSPARENT_ALPHA_CHANNEL_REF, 0.0f};
}
```

---

### Task 3: Create `ffp_light.h/cpp`

**Files:**
- Create: `src/client/ffp/ffp_light.h`
- Create: `src/client/ffp/ffp_light.cpp`

- [ ] **Step 1: Create `ffp_light.h`**

```cpp
#pragma once

#include <SColor.h>
#include <IMeshBuffer.h>
#include <IMesh.h>

// Day/night color blending.
void ffp_blendDayNight(video::SColor *result, u16 light, u32 daynight_ratio);
void ffp_blendDayNight(video::SColor *result, const video::SColor &src, const video::SColorf &dayLight);

// Get the sunlight color for a given daynight_ratio.
video::SColorf ffp_getSunlightColor(u32 daynight_ratio);

// Colorize a mesh buffer with a flat color, applying normal-based shading.
void ffp_colorizeMeshBuffer(scene::IMeshBuffer *buf, const video::SColor &color);

// Set all vertex colors in a mesh to the given color (with normal shading).
void ffp_setMeshColor(scene::IMesh *mesh, const video::SColor &color);
```

- [ ] **Step 2: Create `ffp_light.cpp`**

```cpp
#include "ffp_light.h"
#include "S3DVertex.h"
#include "mapblock_mesh.h" // for encode_light

static void ffp_getSunlightColor(video::SColorf *sunlight, u32 daynight_ratio)
{
	f32 rg = daynight_ratio / 1000.0f - 0.04f;
	f32 b = (0.98f * daynight_ratio) / 1000.0f + 0.078f;
	sunlight->r = rg;
	sunlight->g = rg;
	sunlight->b = b;
}

video::SColorf ffp_getSunlightColor(u32 daynight_ratio)
{
	video::SColorf c;
	ffp_getSunlightColor(&c, daynight_ratio);
	return c;
}

void ffp_blendDayNight(video::SColor *result, u16 light, u32 daynight_ratio)
{
	video::SColorf dayLight;
	ffp_getSunlightColor(&dayLight, daynight_ratio);

	static const video::SColorf artificialColor(1.04f, 1.04f, 1.04f);

	video::SColorf c(encode_light(light, 0));
	f32 n = 1 - c.a;

	f32 r = c.r * (c.a * dayLight.r + n * artificialColor.r) * 2.0f;
	f32 g = c.g * (c.a * dayLight.g + n * artificialColor.g) * 2.0f;
	f32 b = c.b * (c.a * dayLight.b + n * artificialColor.b) * 2.0f;

	static const u8 emphase_blue_when_dark[32] = {
		1, 4, 6, 6, 6, 5, 4, 3, 2, 1, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	};
	b += emphase_blue_when_dark[core::clamp((s32)((r + g + b) / 3 * 255), 0, 255) / 8] / 255.0f;

	result->setRed(core::clamp((s32)(r * 255.0f), 0, 255));
	result->setGreen(core::clamp((s32)(g * 255.0f), 0, 255));
	result->setBlue(core::clamp((s32)(b * 255.0f), 0, 255));
}

void ffp_blendDayNight(video::SColor *result, const video::SColor &data, const video::SColorf &dayLight)
{
	static const video::SColorf artificialColor(1.04f, 1.04f, 1.04f);

	video::SColorf c(data);
	f32 n = 1 - c.a;

	f32 r = c.r * (c.a * dayLight.r + n * artificialColor.r) * 2.0f;
	f32 g = c.g * (c.a * dayLight.g + n * artificialColor.g) * 2.0f;
	f32 b = c.b * (c.a * dayLight.b + n * artificialColor.b) * 2.0f;

	static const u8 emphase_blue_when_dark[32] = {
		1, 4, 6, 6, 6, 5, 4, 3, 2, 1, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	};
	b += emphase_blue_when_dark[core::clamp((s32)((r + g + b) / 3 * 255), 0, 255) / 8] / 255.0f;

	result->setRed(core::clamp((s32)(r * 255.0f), 0, 255));
	result->setGreen(core::clamp((s32)(g * 255.0f), 0, 255));
	result->setBlue(core::clamp((s32)(b * 255.0f), 0, 255));
}

void ffp_colorizeMeshBuffer(scene::IMeshBuffer *buf, const video::SColor &color)
{
	video::S3DVertex *vertices = (video::S3DVertex *)buf->getVertices();
	u32 count = buf->getVertexCount();
	for (u32 i = 0; i < count; i++) {
		vertices[i].Color = color;
		static const v3f light_dir = v3f(1.0f, 1.0f, -0.5f).normalize();
		f32 dot = vertices[i].Normal.dotProduct(light_dir);
		if (dot < 0.0f)
			dot = 0.0f;
		f32 shading = 0.7f + 0.3f * dot;
		vertices[i].Color.setRed((u8)(vertices[i].Color.getRed() * shading));
		vertices[i].Color.setGreen((u8)(vertices[i].Color.getGreen() * shading));
		vertices[i].Color.setBlue((u8)(vertices[i].Color.getBlue() * shading));
	}
}

void ffp_setMeshColor(scene::IMesh *mesh, const video::SColor &color)
{
	for (u32 i = 0; i < mesh->getMeshBufferCount(); i++) {
		auto *buf = mesh->getMeshBuffer(i);
		ffp_colorizeMeshBuffer(buf, color);
		buf->setDirty(scene::EBT_VERTEX);
	}
}
```

---

### Task 4: Create `ffp_render.h/cpp`

**Files:**
- Create: `src/client/ffp/ffp_render.h`
- Create: `src/client/ffp/ffp_render.cpp`

- [ ] **Step 1: Create `ffp_render.h`**

```cpp
#pragma once

#include <vector>
#include "EDriverTypes.h"

std::vector<video::E_DRIVER_TYPE> ffp_getDriverOrder();
bool ffp_shouldEnableVBO();
```

- [ ] **Step 2: Create `ffp_render.cpp`**

```cpp
#include "ffp_render.h"
#include "ffp_settings.h"
#include "IrrlichtDevice.h"

std::vector<video::E_DRIVER_TYPE> ffp_getDriverOrder()
{
	if (ffp_isEnabled()) {
		static const video::E_DRIVER_TYPE drivers[] = {
			video::EDT_OPENGL3,
			video::EDT_OPENGL,
			video::EDT_OGLES2,
			video::EDT_NULL,
		};
		std::vector<video::E_DRIVER_TYPE> result;
		for (auto d : drivers) {
			if (IrrlichtDevice::isDriverSupported(d))
				result.push_back(d);
		}
		return result;
	}
	static const video::E_DRIVER_TYPE drivers[] = {
		video::EDT_OPENGL,
		video::EDT_OPENGL3,
		video::EDT_OGLES2,
		video::EDT_NULL,
	};
	std::vector<video::E_DRIVER_TYPE> result;
	for (auto d : drivers) {
		if (IrrlichtDevice::isDriverSupported(d))
			result.push_back(d);
	}
	return result;
}

bool ffp_shouldEnableVBO()
{
	return ffp_isEnabled();
}
```

---

### Task 5: Create `ffp_mapblock.h/cpp`

**Files:**
- Create: `src/client/ffp/ffp_mapblock.h`
- Create: `src/client/ffp/ffp_mapblock.cpp`

- [ ] **Step 1: Create `ffp_mapblock.h`**

```cpp
#pragma once

#include <map>
#include <vector>
#include <memory>
#include "SColor.h"
#include "SMesh.h"
#include "S3DVertex.h"
#include "irr_ptr.h"

class FFPMapBlockDayNightAnimator {
public:
	FFPMapBlockDayNightAnimator() = default;

	void addLayer(std::vector<video::S3DVertex> &vertices,
			u8 layer, u32 mesh_index);

	bool animate(irr_ptr<scene::IMesh> *meshes, u32 daynight_ratio);

	bool hasAnimation() const { return !m_daynight_diffs.empty(); }

private:
	std::map<std::pair<u8, u32>, std::map<u32, video::SColor>> m_daynight_diffs;
	u32 m_last_daynight_ratio = (u32)-1;
};
```

- [ ] **Step 2: Create `ffp_mapblock.cpp`**

```cpp
#include "ffp_mapblock.h"
#include "ffp_light.h"
#include "S3DVertex.h"

void FFPMapBlockDayNightAnimator::addLayer(
		std::vector<video::S3DVertex> &vertices,
		u8 layer, u32 mesh_index)
{
	video::SColorf sunlight = ffp_getSunlightColor(0);

	std::map<u32, video::SColor> colors;
	for (u32 j = 0; j < vertices.size(); j++) {
		auto &vc = vertices[j];
		video::SColor copy = vc.Color;
		if (vc.Color.getAlpha() == 0) {
			ffp_blendDayNight(&vc.Color, copy, sunlight);
		} else {
			colors[j] = copy;
		}
		vc.Color.setAlpha(255);
	}
	if (!colors.empty())
		m_daynight_diffs[{layer, mesh_index}] = std::move(colors);
}

bool FFPMapBlockDayNightAnimator::animate(
		irr_ptr<scene::IMesh> *meshes, u32 daynight_ratio)
{
	if (daynight_ratio == m_last_daynight_ratio)
		return false;

	video::SColorf day_color = ffp_getSunlightColor(daynight_ratio);

	for (const auto &entry : m_daynight_diffs) {
		auto *mesh = meshes[entry.first.first].get();
		mesh->setDirty(scene::EBT_VERTEX);
		scene::IMeshBuffer *buf = mesh->getMeshBuffer(entry.first.second);
		video::S3DVertex *vertices = (video::S3DVertex *)buf->getVertices();
		for (const auto &ve : entry.second)
			ffp_blendDayNight(&(vertices[ve.first].Color),
					ve.second, day_color);
	}
	m_last_daynight_ratio = daynight_ratio;
	return true;
}
```

---

### Task 6: Add new files to CMakeLists.txt + build

**Files:**
- Modify: `src/client/CMakeLists.txt`

- [ ] **Step 1: Add `.cpp` files to `client_SRCS`**

Insert after line 48 (`clouds.cpp`):

```cmake
	${CMAKE_CURRENT_SOURCE_DIR}/ffp/ffp_settings.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/ffp/ffp_material.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/ffp/ffp_light.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/ffp/ffp_render.cpp
	${CMAKE_CURRENT_SOURCE_DIR}/ffp/ffp_mapblock.cpp
```

- [ ] **Step 2: Build to verify new files compile**

```bash
cmake -B build -DRUN_IN_PLACE=TRUE -DBUILD_UNITTESTS=TRUE 2>&1 | tail -5
cmake --build build -j$(nproc) 2>&1 | tail -30
```

Expected: All 5 new files compile. No link errors (nothing references them yet).

---

### Task 7: Update `hud.cpp` — Use ffp_settings

**Files:**
- Modify: `src/client/hud.cpp`

- [ ] **Step 1: Replace `enable_shaders` local with `ffp_isEnabled()`**

Change line 89:
```
	bool enable_shaders = g_settings->getBool("enable_shaders");
```
→ Remove this local variable entirely.

Change the selection material branch (lines 90-97):
```cpp
	if (m_mode == HIGHLIGHT_HALO) {
		if (enable_shaders) {
			auto shader_id = shdrsrc->getShaderRaw("selection_shader", true);
			m_selection_material.MaterialType = shdrsrc->getShaderInfo(shader_id).material;
		} else {
			m_selection_material.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL;
		}
	}
```
→ replace `enable_shaders` with `ffp_isEnabled()`.

Change the block bounds material branch (lines 111-116):
```cpp
	if (enable_shaders) {
		m_block_bounds_material.MaterialType = video::EMT_SOLID;
	} else {
		m_block_bounds_material.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL;
	}
```
→ replace `enable_shaders` with `ffp_isEnabled()`.

Add `#include "ffp/ffp_settings.h"`.

- [ ] **Step 2: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -10
```

Expected: Build passes.

---

### Task 8: Update `minimap.cpp/h` — Use ffp_settings

**Files:**
- Modify: `src/client/minimap.h`
- Modify: `src/client/minimap.cpp`

- [ ] **Step 1: Remove `m_enable_shaders` from `minimap.h`**

Delete `bool m_enable_shaders;`.

- [ ] **Step 2: Update `minimap.cpp`**

Remove line `m_enable_shaders = g_settings->getBool("enable_shaders");`.

Change surface material branch:
```cpp
		if (m_enable_shaders) {
			auto sid = m_shdrsrc->getShaderRaw("minimap_shader", true);
			material.MaterialType = m_shdrsrc->getShaderInfo(sid).material;
		} else {
			material.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL_REF;
		}
```
→ replace `m_enable_shaders` with `ffp_isEnabled()`.

Add `#include "ffp/ffp_settings.h"`.

- [ ] **Step 3: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -10
```

Expected: Build passes.

---

### Task 9: Update `clouds.cpp/h` — Use ffp_settings + ffp_light

**Files:**
- Modify: `src/client/clouds.h`
- Modify: `src/client/clouds.cpp`

- [ ] **Step 1: Remove `m_enable_shaders` from `clouds.h`**

Delete `bool m_enable_shaders = false;`.

- [ ] **Step 2: Update `clouds.cpp`**

Remove `m_enable_shaders = g_settings->getBool("enable_shaders");`.

Change cloud shader material branch:
```cpp
	if (m_enable_shaders) {
		auto sid = ssrc->getShaderRaw("cloud_shader", true);
		m_material.MaterialType = ssrc->getShaderInfo(sid).material;
	} else {
		m_material.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL;
	}
```
→ replace `m_enable_shaders` with `ffp_isEnabled()`.

Change vertex color line:
```cpp
	video::SColorf c_top_f = m_enable_shaders ? video::SColorf(1, 1, 1, 1) : m_color;
```
→ replace `m_enable_shaders` with `ffp_isEnabled()`.

Change ColorParam guard:
```cpp
	m_material.ColorParam = m_color.toSColor();
```
→
```cpp
	if (ffp_isEnabled())
		m_material.ColorParam = m_color.toSColor();
```

Add `#include "ffp/ffp_settings.h"`.

- [ ] **Step 3: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -10
```

Expected: Build passes.

---

### Task 10: Update `sky.cpp/h` — Use ffp_settings + ffp_light

**Files:**
- Modify: `src/client/sky.h`
- Modify: `src/client/sky.cpp`

- [ ] **Step 1: Remove `m_enable_shaders` from `sky.h`**

Delete `bool m_enable_shaders = false;`.

- [ ] **Step 2: Update `sky.cpp`**

Remove `m_enable_shaders = g_settings->getBool("enable_shaders");`.

Change star shader material branch:
```cpp
	if (m_enable_shaders) {
		m_materials[0].MaterialType =
				ssrc->getShaderInfo(ssrc->getShaderRaw("stars_shader", true)).material;
	} else {
		m_materials[0].MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL;
	}
```
→ replace `m_enable_shaders` with `ffp_isEnabled()`.

Change `draw_stars` ColorParam guard:
```cpp
	if (m_enable_shaders) {
		m_materials[0].ColorParam = color.toSColor();
	} else {
		setMeshBufferColor(m_stars.get(), color.toSColor());
	}
```
→ replace `m_enable_shaders` with `ffp_isEnabled()`, and replace `setMeshBufferColor` with `ffp_setMeshColor`.

Change `updateStars` EHM_STATIC guard:
```cpp
	if (m_enable_shaders)
		m_stars->setHardwareMappingHint(scene::EHM_STATIC);
```
→ Remove entirely.

Add `#include "ffp/ffp_settings.h"` and `#include "ffp/ffp_light.h"`.

- [ ] **Step 3: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -10
```

Expected: Build passes.

---

### Task 11: Update `mesh.h/cpp` — Remove FFP overload

**Files:**
- Modify: `src/client/mesh.h`
- Modify: `src/client/mesh.cpp`

- [ ] **Step 1: Remove FFP `colorizeMeshBuffer` declaration from `mesh.h`**

Delete:
```cpp
void colorizeMeshBuffer(scene::IMeshBuffer *buf, const video::SColor *buffercolor);
```

- [ ] **Step 2: Remove FFP `colorizeMeshBuffer` implementation from `mesh.cpp`**

Delete the overload that takes `const video::SColor *`:
```cpp
void colorizeMeshBuffer(scene::IMeshBuffer *buf, const video::SColor *buffercolor)
{
	applyToMeshBuffer(buf, [buffercolor](auto *vertex) {
		vertex->Color = *buffercolor;
		applyFacesShading(vertex->Color, vertex->Normal);
	});
}
```

- [ ] **Step 3: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -10
```

Expected: Build passes.

---

### Task 12: Update `game.cpp` and `clientenvironment.cpp` — Use ffp_blendDayNight

Update these BEFORE final_color_blend is removed from mapblock_mesh.h in Task 13.

**Files:**
- Modify: `src/client/game.cpp`
- Modify: `src/client/clientenvironment.cpp`

- [ ] **Step 1: Update `game.cpp`**

Change:
```
	final_color_blend(&c, light_level, daynight_ratio);
```
→
```
	ffp_blendDayNight(&c, light_level, daynight_ratio);
```

- [ ] **Step 2: Update `clientenvironment.cpp`**

Change:
```
	final_color_blend(&lplayer->light_color, light, day_night_ratio);
```
→
```
	ffp_blendDayNight(&lplayer->light_color, light, day_night_ratio);
```

- [ ] **Step 3: Add includes**

Ensure both files include `"ffp/ffp_light.h"`.

- [ ] **Step 4: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -10
```

Expected: Build passes. `final_color_blend` is no longer called from game.cpp or clientenvironment.cpp.

---

### Task 13: Update `mapblock_mesh.cpp/h` — Use ffp_mapblock + ffp_light

**Files:**
- Modify: `src/client/mapblock_mesh.h`
- Modify: `src/client/mapblock_mesh.cpp`

- [ ] **Step 1: Update `mapblock_mesh.h`**

Remove these function declarations:
```
void get_sunlight_color(video::SColorf *sunlight, u32 daynight_ratio);
void final_color_blend(video::SColor *result, u16 light, u32 daynight_ratio);
void final_color_blend(video::SColor *result, const video::SColor &data, const video::SColorf &dayLight);
```

Remove these FFP member variables:
```
bool m_enable_shaders;
u32 m_last_daynight_ratio = (u32)-1;
std::map<std::pair<u8, u32>, std::map<u32, video::SColor>> m_daynight_diffs;
```

Add include and new member:
```cpp
#include "ffp/ffp_mapblock.h"

// In class members:
std::unique_ptr<FFPMapBlockDayNightAnimator> m_daynight_animator;
```

- [ ] **Step 2: Update `mapblock_mesh.cpp` constructor**

Replace `m_enable_shaders = data->m_use_shaders;` with:
```cpp
	m_daynight_animator = std::make_unique<FFPMapBlockDayNightAnimator>();
```

Replace the inline FFP day/night color extraction block:
```cpp
			// Extract colors for day-night animation (FFP path)
			if (!m_enable_shaders) {
				video::SColorf sunlight;
				get_sunlight_color(&sunlight, 0);

				std::map<u32, video::SColor> colors;
				const u32 vertex_count = p.vertices.size();
				for (u32 j = 0; j < vertex_count; j++) {
					video::SColor *vc = &p.vertices[j].Color;
					video::SColor copy = *vc;
					if (vc->getAlpha() == 0)
						final_color_blend(vc, copy, sunlight);
					else
						colors[j] = copy;
					vc->setAlpha(255);
				}
				if (!colors.empty())
					m_daynight_diffs[{layer, i}] = std::move(colors);
			}
```
→
```cpp
			m_daynight_animator->addLayer(p.vertices, layer, i);
```

Replace the `m_has_animation` line:
```cpp
	m_has_animation =
		!m_crack_materials.empty() ||
		!m_daynight_diffs.empty() ||
		!m_animation_info.empty();
```
→
```cpp
	m_has_animation =
		!m_crack_materials.empty() ||
		m_daynight_animator->hasAnimation() ||
		!m_animation_info.empty();
```

Replace the `if (m_enable_shaders)` material branch:
```cpp
			if (g_settings->getBool("enable_shaders")) {
				material.MaterialType = m_shdrsrc->getShaderInfo(
						p.layer.shader_id).material;
				p.layer.applyMaterialOptionsWithShaders(material, layer);
			} else {
				p.layer.applyMaterialOptions(material);
			}
```
→
```cpp
			if (ffp_isEnabled()) {
				material.MaterialType = m_shdrsrc->getShaderInfo(
						p.layer.shader_id).material;
				p.layer.applyMaterialOptionsWithShaders(material, layer);
			} else {
				ffp_applyTileMaterial(material, p.layer);
			}
```

- [ ] **Step 3: Update `mapblock_mesh.cpp` animate()**

Replace the inline day/night animation block:
```cpp
	// Day-night transition (FFP path)
	if (!m_enable_shaders && (daynight_ratio != m_last_daynight_ratio)) {
		video::SColorf day_color;
		get_sunlight_color(&day_color, daynight_ratio);

		for (auto &daynight_diff : m_daynight_diffs) {
			auto *mesh = m_mesh[daynight_diff.first.first].get();
			mesh->setDirty(scene::EBT_VERTEX);
			scene::IMeshBuffer *buf = mesh->
				getMeshBuffer(daynight_diff.first.second);
			video::S3DVertex *vertices = (video::S3DVertex *)buf->getVertices();
			for (const auto &j : daynight_diff.second)
				final_color_blend(&(vertices[j.first].Color), j.second,
						day_color);
		}
		m_last_daynight_ratio = daynight_ratio;
	}
```
→
```cpp
	m_daynight_animator->animate(m_mesh, daynight_ratio);
```

Remove `#include "settings.h"` if it's no longer needed (check for other uses in the file).

Add `#include "ffp/ffp_settings.h"` and `#include "ffp/ffp_material.h"`.

- [ ] **Step 4: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

Expected: Build passes.

---

### Task 14: Update `content_cao.cpp/h` — Use ffp_material + ffp_light

**Files:**
- Modify: `src/client/content_cao.h`
- Modify: `src/client/content_cao.cpp`

- [ ] **Step 1: Update `content_cao.h`**

Remove:
```
	f32 m_material_type_param = 0.0f;
	bool m_enable_shaders = false;
```

- [ ] **Step 2: Update `content_cao.cpp`**

Remove `m_enable_shaders = g_settings->getBool("enable_shaders");`.

Change `generateNodeMesh` material branch:
```cpp
		if (g_settings->getBool("enable_shaders")) {
			p.layer.applyMaterialOptionsWithShaders(mat, layer);
			getAdHocNodeShader(mat, shdsrc, "object_shader", alpha_mode, layer == 1);
		} else {
			p.layer.applyMaterialOptions(mat);
		}
```
→
```cpp
		if (ffp_isEnabled()) {
			p.layer.applyMaterialOptionsWithShaders(mat, layer);
			getAdHocNodeShader(mat, shdsrc, "object_shader", alpha_mode, layer == 1);
		} else {
			ffp_applyTileMaterial(mat, p.layer);
		}
```

Change `addToScene` entity material branch:
```cpp
			if (m_enable_shaders) {
				IShaderSource *shader_source = m_client->getShaderSource();
				MaterialType material_type;
				if (m_prop.shaded && m_prop.glow == 0)
					material_type = (m_prop.use_texture_alpha) ?
						TILE_MATERIAL_ALPHA : TILE_MATERIAL_BASIC;
				else
					material_type = (m_prop.use_texture_alpha) ?
						TILE_MATERIAL_PLAIN_ALPHA : TILE_MATERIAL_PLAIN;
				u32 shader_id = shader_source->getShader("object_shader", material_type, NDT_NORMAL,
					false, hw_skin);
				m_material_type = shader_source->getShaderInfo(shader_id).material;
			} else {
				if (m_prop.use_texture_alpha) {
					m_material_type = video::EMT_TRANSPARENT_ALPHA_CHANNEL;
					m_material_type_param = 1.0f / 256.f;
				} else {
					m_material_type = video::EMT_TRANSPARENT_ALPHA_CHANNEL_REF;
				}
			}
```
→
```cpp
			if (ffp_isEnabled()) {
				IShaderSource *shader_source = m_client->getShaderSource();
				MaterialType material_type;
				if (m_prop.shaded && m_prop.glow == 0)
					material_type = (m_prop.use_texture_alpha) ?
						TILE_MATERIAL_ALPHA : TILE_MATERIAL_BASIC;
				else
					material_type = (m_prop.use_texture_alpha) ?
						TILE_MATERIAL_PLAIN_ALPHA : TILE_MATERIAL_PLAIN;
				u32 shader_id = shader_source->getShader("object_shader", material_type, NDT_NORMAL,
					false, hw_skin);
				m_material_type = shader_source->getShaderInfo(shader_id).material;
			} else {
				auto ffp_mat = ffp_getEntityMaterial(m_prop.use_texture_alpha);
				m_material_type = ffp_mat.type;
			}
```

Change `addToScene` ColorParam guard:
```cpp
			buf->getMaterial().ColorParam = c;
```
→
```cpp
			if (ffp_isEnabled())
				buf->getMaterial().ColorParam = c;
```

Change `updateLight`:
```cpp
	if (m_enable_shaders)
		light = encode_light(light_at_pos, m_prop.glow);
	else
		final_color_blend(&light, light_at_pos, day_night_ratio);
```
→
```cpp
	if (ffp_isEnabled())
		light = encode_light(light_at_pos, m_prop.glow);
	else
		ffp_blendDayNight(&light, light_at_pos, day_night_ratio);
```

Change `setNodeLight`:
```cpp
	if (!m_enable_shaders) {
		if (light_color.getAlpha() == 0)
			return;
		if (m_meshnode) {
			setMeshColor(m_meshnode->getMesh(), light_color);
		} else if (m_animated_meshnode) {
			setMeshColor(m_animated_meshnode->getMesh(), light_color);
		} else if (m_spritenode) {
			m_spritenode->setColor(light_color);
		}
		return;
	}

	auto *node = getSceneNode();
	if (!node)
		return;
	setColorParam(node, light_color);
```
→
```cpp
	if (!ffp_isEnabled()) {
		if (light_color.getAlpha() == 0)
			return;
		if (m_meshnode) {
			ffp_setMeshColor(m_meshnode->getMesh(), light_color);
		} else if (m_animated_meshnode) {
			ffp_setMeshColor(m_animated_meshnode->getMesh(), light_color);
		} else if (m_spritenode) {
			m_spritenode->setColor(light_color);
		}
		return;
	}

	auto *node = getSceneNode();
	if (!node)
		return;
	setColorParam(node, light_color);
```

Add `#include "ffp/ffp_settings.h"`, `#include "ffp/ffp_material.h"`, `#include "ffp/ffp_light.h"`.

- [ ] **Step 3: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

Expected: Build passes.

---

### Task 15: Update `wieldmesh.cpp/h` — Use ffp_material + ffp_light

**Files:**
- Modify: `src/client/wieldmesh.h`
- Modify: `src/client/wieldmesh.cpp`

- [ ] **Step 1: Remove `m_enable_shaders` from `wieldmesh.h`**

Delete `bool m_enable_shaders;`.

- [ ] **Step 2: Update `wieldmesh.cpp`**

Remove `m_enable_shaders = g_settings->getBool("enable_shaders");`.

Change `createGenericNodeMesh` material branch:
```cpp
			if (g_settings->getBool("enable_shaders"))
				p.layer.applyMaterialOptionsWithShaders(buf->Material, layer);
			else
				p.layer.applyMaterialOptions(buf->Material);
```
→
```cpp
			if (ffp_isEnabled())
				p.layer.applyMaterialOptionsWithShaders(buf->Material, layer);
			else
				ffp_applyTileMaterial(buf->Material, p.layer);
```

Change `setItem`:
```cpp
	if (m_enable_shaders) {
		u32 shader_id = shdsrc->getShader("object_shader", TILE_MATERIAL_BASIC, NDT_NORMAL);
		m_material_type = shdsrc->getShaderInfo(shader_id).material;
```
→
```cpp
	if (ffp_isEnabled()) {
		u32 shader_id = shdsrc->getShader("object_shader", TILE_MATERIAL_BASIC, NDT_NORMAL);
		m_material_type = shdsrc->getShaderInfo(shader_id).material;
```

Change `setColor`:
```cpp
			if (m_enable_shaders)
				setMeshBufferColor(buf, buffercolor);
			else
				colorizeMeshBuffer(buf, &buffercolor);
```
→
```cpp
			if (ffp_isEnabled())
				setMeshBufferColor(buf, buffercolor);
			else
				ffp_colorizeMeshBuffer(buf, buffercolor);
```

Change `setNodeLightColor`:
```cpp
	if (m_enable_shaders) {
		for (u32 i = 0; i < m_meshnode->getMaterialCount(); ++i) {
			video::SMaterial &material = m_meshnode->getMaterial(i);
			material.ColorParam = color;
		}
	} else {
		setColor(color);
	}
```
→ replace `m_enable_shaders` with `ffp_isEnabled()`.

Change `changeToMesh`:
```cpp
		if (m_enable_shaders)
			mesh->setHardwareMappingHint(scene::EHM_STATIC);
		else
			mesh->setHardwareMappingHint(scene::EHM_DYNAMIC);
```
→
```cpp
		if (ffp_isEnabled())
			mesh->setHardwareMappingHint(scene::EHM_STATIC);
		else
			mesh->setHardwareMappingHint(scene::EHM_DYNAMIC);
```

Add `#include "ffp/ffp_settings.h"`, `#include "ffp/ffp_material.h"`, `#include "ffp/ffp_light.h"`.

- [ ] **Step 3: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

Expected: Build passes.

---

### Task 16: Update `renderingengine.cpp` + `render/plain.cpp` — Use ffp_render + ffp_settings

**Files:**
- Modify: `src/client/renderingengine.cpp`
- Modify: `src/client/render/plain.cpp`

- [ ] **Step 1: Update `renderingengine.cpp`**

Replace VBO line:
```
	driver->setVBOEnabled(g_settings->getBool("enable_shaders"));
```
→
```
	driver->setVBOEnabled(ffp_shouldEnableVBO());
```

Replace the entire driver ordering function:
```
std::vector<video::E_DRIVER_TYPE> RenderingEngine::getSupportedVideoDrivers()
{
	std::vector<video::E_DRIVER_TYPE> drivers;

	if (!g_settings->getBool("enable_shaders")) {
		static const video::E_DRIVER_TYPE glDrivers[] = {
			video::EDT_OPENGL,
			video::EDT_OPENGL3,
			video::EDT_OGLES2,
			video::EDT_NULL,
		};
		for (auto driver : glDrivers) {
			if (IrrlichtDevice::isDriverSupported(driver))
				drivers.push_back(driver);
		}
	} else {
		static const video::E_DRIVER_TYPE glDrivers[] = {
			video::EDT_OPENGL3,
			video::EDT_OPENGL,
			video::EDT_OGLES2,
			video::EDT_NULL,
		};
		for (auto driver : glDrivers) {
			if (IrrlichtDevice::isDriverSupported(driver))
				drivers.push_back(driver);
		}
	}
	return drivers;
}
```
→
```
std::vector<video::E_DRIVER_TYPE> RenderingEngine::getSupportedVideoDrivers()
{
	return ffp_getDriverOrder();
}
```

Add `#include "ffp/ffp_settings.h"`, `#include "ffp/ffp_render.h"`.

- [ ] **Step 2: Update `render/plain.cpp`**

Replace line 96:
```
	if (g_settings->getBool("enable_shaders") && g_settings->getBool("enable_post_processing")) {
```
→
```
	if (ffp_isEnabled() && g_settings->getBool("enable_post_processing")) {
```

Replace line 122:
```
	if (g_settings->getBool("enable_shaders") && g_settings->getBool("enable_post_processing"))
```
→
```
	if (ffp_isEnabled() && g_settings->getBool("enable_post_processing"))
```

Add `#include "ffp/ffp_settings.h"`.

- [ ] **Step 3: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

Expected: Build passes.

---

### Task 17: Update remaining files — `shader.cpp`, `mesh_generator_thread.cpp/h`, `environment.cpp/h`

**Files:**
- Modify: `src/client/shader.cpp`
- Modify: `src/client/mesh_generator_thread.h`
- Modify: `src/client/mesh_generator_thread.cpp`
- Modify: `src/client/environment.h`
- Modify: `src/client/environment.cpp`

- [ ] **Step 1: `shader.cpp`** — no change needed (uses local `m_enabled` not `enable_shaders` setting)

Note: `shader.cpp` already has a clean abstraction — it caches `m_enabled` locally and checks it. No change needed since this is already isolated.

- [ ] **Step 2: `mesh_generator_thread.h`** — remove `m_cache_enable_shaders`

Delete `bool m_cache_enable_shaders;`.

- [ ] **Step 3: `mesh_generator_thread.cpp`** — use `ffp_isEnabled()`

Remove `m_cache_enable_shaders = g_settings->getBool("enable_shaders");`.

Change the `fillDataFromMapBlocks` call:
```
			m_cache_enable_shaders);
```
→
```
			ffp_isEnabled());
```

Add `#include "ffp/ffp_settings.h"`.

- [ ] **Step 4: `environment.h`** — remove `m_cache_enable_shaders`

Delete `bool m_cache_enable_shaders;`.

- [ ] **Step 5: `environment.cpp`** — remove unused initialization

Remove `m_cache_enable_shaders(g_settings->getBool("enable_shaders"))`.

- [ ] **Step 6: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

Expected: Build passes.

---

### Task 18: Revert `tile.h/cpp` to upstream + update callers

**Files:**
- Modify: `src/client/tile.h`
- Modify: `src/client/tile.cpp`
- Modify: `src/client/content_cao.cpp`
- Modify: `src/client/wieldmesh.cpp`
- Modify: `src/client/mapblock_mesh.cpp`
- Modify: `src/client/content_mapblock.cpp` (if it uses the renamed function)

- [ ] **Step 1: Revert `tile.h`**

Remove the FFP variant declaration:
```
	void applyMaterialOptions(video::SMaterial &material) const;
```

Rename `applyMaterialOptionsWithShaders` back to the original:
```
	void applyMaterialOptions(video::SMaterial &material, int layer) const;
```

Update the doc comment to remove the `@note` about not setting MaterialType.

- [ ] **Step 2: Revert `tile.cpp`**

Remove the FFP variant implementation:
```
void TileLayer::applyMaterialOptions(video::SMaterial &material) const
{
	... 36 lines ...
}
```

Rename `applyMaterialOptionsWithShaders` back to `applyMaterialOptions`:
```
void TileLayer::applyMaterialOptions(video::SMaterial &material, int layer) const
```

- [ ] **Step 3: Update all callers**

In each caller, replace `applyMaterialOptionsWithShaders(mat, layer)` with `applyMaterialOptions(mat, layer)`:

- `src/client/content_cao.cpp` line 240
- `src/client/wieldmesh.cpp` line 380
- `src/client/mapblock_mesh.cpp` line 732
- `src/client/content_mapblock.cpp` (if it has a call)

Use `replaceAll` across each file to make these changes.

- [ ] **Step 4: Build check**

```bash
cmake --build build -j$(nproc) 2>&1 | tail -20
```

Expected: Build passes. `tile.h/cpp` now has zero diff from upstream.

---

### Task 19: Full build + run tests

- [ ] **Step 1: Clean rebuild**

```bash
cmake -B build -DRUN_IN_PLACE=TRUE -DBUILD_UNITTESTS=TRUE
cmake --build build -j$(nproc) 2>&1 | tail -30
```

Expected: Clean compile, no errors.

- [ ] **Step 2: Run unit tests**

```bash
./bin/luanti --run-unittests 2>&1 | tail -30
```

Expected: All test modules pass.

- [ ] **Step 3: Verify `tile.h/cpp` has no diff**

```bash
git diff -- src/client/tile.h src/client/tile.cpp
```

Expected: No output (zero changes from upstream for these files).

---

### Task 20: Final verification

- [ ] **Step 1: Full rebuild**

```bash
cmake -B build -DRUN_IN_PLACE=TRUE -DBUILD_UNITTESTS=TRUE && cmake --build build -j$(nproc)
```

- [ ] **Step 2: Run all tests**

```bash
./bin/luanti --run-unittests
```

- [ ] **Step 3: Check for remaining FFP inlines**

```bash
# These should now only appear in ffp/ or shader.cpp (which has its own pattern)
git diff master..HEAD -- src/ | grep -c "m_enable_shaders\|enable_shaders.*getBool"
```

Expected: zero or near-zero remaining references outside `ffp/` and `shader.cpp`.
