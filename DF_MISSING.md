# DragonfireClient — Features Not Yet Ported

These are DF features that exist in the old `big_rebase` branch but have
not yet been ported to modern Luanti master on `df-rebased`. Each entry
notes why the port is non-trivial.

## Camera — Nametag Images (`src/client/camera.cpp`, `src/client/camera.h`)

**What changed in DF:**
- `Nametag` struct expanded with `images` / `images_dim` / `texture_source` fields
- `addNametag()` signature changed from `(const Nametag &params)` to individual
  parameters plus an `image_names` vector
- Some FOV bookkeeping renamed (`m_old_fov_degrees` added)
- `CameraMode` changed from `enum class` to plain `enum`
- `updateWieldedTool()` inlined into `wield()`

**Why it's hard:**
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


