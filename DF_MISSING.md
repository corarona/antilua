# DragonfireClient — Features Not Yet Ported

These are DF features that exist in the old `big_rebase` branch but have
not yet been ported to modern Luanti master on `df-rebased`. Each entry
notes why the port is non-trivial.

## Recently Ported (from CloakV4)

| Feature | Commit | Date |
|---------|--------|------|
| Freecam (detached camera + legit position freeze) | `62506474f` | 2026-05-26 |
| Fullbright (max brightness via decode_light override) | `9919217de` | 2026-05-26 |
| Xray (selectively hide nodes at mesh gen time) | `2d36fd5c4` | 2026-05-26 |
| Cheat menu Y offset (dynamic below recent chat) | `62506474f` | 2026-05-26 |

---

## Camera — Freecam & Nametag Images (`src/client/camera.cpp`, `src/client/camera.h`)

**Status**: Freecam ✅ ported (see commit `62506474f`). Nametag images ❌ not yet.

**What changed in DF (freecam, now ported):**
- Freecam mode: camera detaches from player position when `freecam` setting is on
- Legit position/speed tracking for network freeze during freecam
- `freecamEnable()` / `freecamDisable()` save/restore player position
- `getLegitPosition()` / `getSendSpeed()` report pre-freecam state to server
- Mesh culling and visibility overrides for first-person player model

**What remains (nametag images):**
- `Nametag` struct expanded with `images` / `images_dim` / `texture_source` fields
- `addNametag()` signature changed from `(const Nametag &params)` to individual
  parameters plus an `image_names` vector
- Some FOV bookkeeping renamed (`m_old_fov_degrees` added)
- `CameraMode` changed from `enum class` to plain `enum`
- `updateWieldedTool()` inlined into `wield()`

**Why nametag images are hard:**
- The `Nametag` struct in luanti master is simpler — uses `std::optional<SColor>`
  for `bgcolor` (DF used a custom `Optional<T>` wrapper). The struct layout and
  `getBgColor()` logic differ slightly.
- `Camera::update()` in luanti master references player fields that DF renamed
  (e.g. `LocalPlayer::gravity` vs the `physics_override` struct).
- `WieldMeshSceneNode` API changed (`setNodeLightColor` removed).
- The `ICameraSceneNode` / `ISceneNode` include chain differs (luanti uses
  forward declarations more aggressively).

---

## ESP & Tracers Rendering (`src/client/render/core.cpp`, `src/client/render/core.h`)

**DF diff**: New `drawTracersAndESP()` method; render pipeline restructured.

**What changed in DF:**
- `RenderingCore::drawTracersAndESP()` renders entity/player ESP boxes,
  entity/player tracers, node ESP, and node tracers
- Draws coloured bounding boxes around objects with `enable_*_esp` settings
- Draws lines from camera to objects with `enable_*_tracers` settings
- Configurable colours via `entity_esp_color`, `player_esp_color`, etc.
- DF removed the modular `RenderPipeline`/`PipelineStep` architecture that
  luanti master uses

**Why it's hard:**
- Luanti master has a pipeline-based renderer (`RenderPipeline`, `PipelineStep`,
  `secondstage.cpp`). DF replaced this with a simpler direct-render approach.
- The DF rendering code accesses internal Irrlicht state (`IVideoDriver`,
  `ISceneManager`, `ICameraSceneNode`) in ways that differ from luanti's
  current pipeline architecture.
- Needs the camera to provide camera position/orientation in the right format.

---

## ContentCAO — Nametag Images (`src/client/content_cao.cpp`, `src/client/content_cao.h`)

**DF diff**: ~moderate (nametag_images member + updateNametag changes)

**What changed in DF:**
- `GenericCAO::nametag_images` (`std::vector<std::string>`) member added
- `GenericCAO::updateNametag()` passes `nametag_images` to `addNametag()`
- The `ClientObjectRef::l_set_nametag_images()` Lua method depends on this

**Why it's hard:**
- `addNametag()` in luanti master takes `const Nametag &params` — to support
  images, the `Nametag` struct itself must be extended first (see camera entry).
- The `set_nametag_images` method is currently commented out in
  `l_clientobject.cpp` with a FIXME comment.

---

## Player — Physics Override Refactor (`src/client/localplayer.cpp`, `src/client/localplayer.h`)

**Status**: Freecam methods ✅ ported. Physics override flat fields ❌ not yet.

**What changed in DF (freecam, now ported):**
- `freecamEnable()` / `freecamDisable()` methods — save/restore player
  position when toggling freecam
- `getLegitPosition()` / `getSendSpeed()` — report pre-freecam position/speed
  to the server during freecam
- `moveFreecam()` / `applyFreecamControl()` — separate freecam movement
- `empty_control` / `lua_control` — input isolation during freecam

**What remains (physics refactor):**
- Physics override fields changed from a struct
  (`PlayerPhysicsOverride physics_override`) to flat member fields
  (`physics_override_speed`, `physics_override_jump`, `physics_override_gravity`,
  `physics_override_sneak`, `physics_override_sneak_glitch`,
  `physics_override_new_move`)
- `isWaitingForReattach()` / `tryReattach()` — entity_speed reattach logic

**Why physics refactor is hard:**
- The flat-field change cascades through `localplayer.cpp`, `player.cpp`,
  `client.cpp`, `clientenvironment.cpp` — all need updating together.
- `move()` signature changed (added `f32 pos_max_d` parameter).
- `PlayerSettings` class was removed from `localplayer.h` and moved to `player.h`.
- The gravity/acceleration system interacts with `clientenvironment.cpp`.

---

## Client — Mod Loading & Constructor (`src/client/client.cpp`, `src/client/client.h`)

**DF diff**: ~massive (constructor, mod loading, protocol changes)

**What changed in DF:**
- `Client::loadMods()` — replaced SSCSM-based mod loading with direct
  `clientmods/` directory scanning
- Constructor signature changed (added `GameUI *game_ui`, removed
  `ItemVisualsManager`, added `address_name`, removed SSCSM references)
- `ClientDynamicInfo` removed
- `sendPlayerPos()` simplified (fewer fields, keep-alive mechanism removed)
- Sound system replaced (`ISoundManager *` instead of
  `std::unique_ptr<ISoundManager>`)
- Mesh update system changed (`MeshUpdateManager` → direct
  `MeshUpdateThread` member)

**Why it's hard:**
- Constructor changes touch every instantiation site.
- Protocol changes (player position, init, client info) need to match server
  expectations.
- The sound system replacement is a separate large change.

---

## Network — Protocol Simplification

**DF diff**: Multiple files (`network/clientpackethandler.cpp`, `client.cpp`, etc.)

**What changed in DF:**
- Removed several TOCLIENT handlers (`MovePlayerRel`, `DeathScreenLegacy`,
  `SpawnParticleBatch`, `Camera`)
- Simplified packet structures (player position, init sequence)
- Reduced compression options

**Why it's hard:**
- Protocol changes must be coordinated with server code.
- luanti master's protocol has evolved significantly since DF forked.
