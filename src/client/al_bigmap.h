// Antilua — per-server minimap persistence + client-side "big map"
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "irrlichttypes.h"
#include "irr_v2d.h"
#include "irr_v3d.h"
#include "rect.h"
#include "SColor.h"
#include "CMeshBuffer.h"
#include "irr_ptr.h"

#include <map>
#include <set>
#include <memory>
#include <string>
#include <vector>

class Client;
struct MinimapMapblock;
class NodeDefManager;

namespace video {
	class IImage;
	class IVideoDriver;
	class ITexture;
}

// One saved minimap pixel. Self-contained: the node content id is stored
// together with the node name it had at save time, so blocks can be remapped
// to the current session's content ids on load.
struct AlBigMapPixel {
	u16 param0;   // content id at save time
	u8  param1;
	u8  param2;
	u16 height;   // relative to block base (0..15)
	u16 air_count;
};

// A saved 16x16 minimap block. `name_map` maps the content ids used in this
// block to their node names at save time (needed for cross-session remap).
struct AlBigMapBlock {
	v3s16 pos;
	std::map<u16, std::string> name_map;
	std::vector<AlBigMapPixel> pixels; // 256 entries, indexed z*16+x
};

/**
 * Captures the client-derived minimap blocks (`MinimapMapblock`s) as they
 * stream in, persists them per server, and provides a fullscreen "big map"
 * composed from every saved block.
 *
 * Storage layout:
 *   remote:      ~/.antilua/data/server/<addr>_<port>/minimap/blocks/
 *   singleplayer: <world_path>/minimap/blocks/
 *
 * One file per block (self-contained, carries its own name<->id mapping), so
 * no nodedef table needs to be stored or re-serialized.
 */
class AlBigMap
{
public:
	AlBigMap(Client *client);
	~AlBigMap();

	// Block capture (main thread, called from the minimap block delivery hook).
	void onBlockAdded(v3s16 pos, const MinimapMapblock *data);

	// Session lifecycle (called from AlClientHooks).
	void onConnect();
	void onDisconnect();

	// Per-frame update: input + throttled disk flushing. Returns 1 if the map
	// was opened, 2 if it was closed this step, 0 otherwise.
	int step(float dtime);

	// View control.
	bool isOpen() const { return m_open; }
	void open();
	void close();
	void toggle() { if (m_open) close(); else open(); }

	// The currently-open big map instance (if any). Used by the input handler
	// to close the map when ESC is pressed.
	static AlBigMap *getActive();
	static void closeActive();

	v2s32 getCenterNode() const { return m_center; }
	void setCenterNode(v2s32 c);
	void pan(v2s32 delta_nodes);
	float getZoom() const { return m_zoom; }
	void setZoom(float z);
	bool getFollowPlayer() const { return m_follow_player; }
	void setFollowPlayer(bool f) { m_follow_player = f; }

	// Persistence control.
	void setSaveEnabled(bool e) { m_save_enabled = e; }
	bool getSaveEnabled() const { return m_save_enabled; }
	void save();    // flush all pending writes
	void load();    // (re)load all saved blocks from disk
	void clear();   // wipe memory + disk for this server

	std::string getSaveDir() const;
	std::string getBlocksDir() const;
	// Directory where rendered map sections are saved as PNGs (registered as
	// a texture search dir so formspec image elements can reference them).
	std::string getImagesDir() const;
	size_t getBlockCount() const;
	bool hasBlock(v3s16 block_pos) const;
	void getCoverage(v3s16 *min_pos, v3s16 *max_pos) const;

	// Renders the saved map region around `center` (node coords, x/z) with
	// the given `size` (in nodes) to a PNG in the images dir and returns the
	// texture name for use in formspec image elements, or "" on failure.
	std::string renderSectionToImage(v3s32 center, v3s32 size);

	// Deletes all rendered section PNGs in the images dir.
	void clearImages();

	// Data access for the Lua API (node coordinates, x/z).
	bool getPixel(v2s32 node_pos, std::string *name, u8 *param2,
			u16 *height, u16 *air_count) const;
	bool setPixel(v2s32 node_pos, const std::string &name,
			u16 height, u16 air_count, u8 param2);
	bool getBlock(v3s16 block_pos, AlBigMapBlock **out) const;

	// Rendering (main thread). Ensures the view texture is up to date for the
	// given target size, then draws it fullscreen.
	void draw(video::IVideoDriver *driver, v2u32 target_size);

	Client *getClient() const { return m_client; }

private:
	static AlBigMap *s_active;

	std::string resolveSaveDir() const;
	void writeBlockToDisk(const AlBigMapBlock &block) const;
	bool readBlockFromDisk(const std::string &path, AlBigMapBlock &block) const;

	video::SColor pixelColor(const AlBigMapBlock &block, size_t idx) const;
	// Ensure the 16x16 color tile for a block is cached (current nodedef).
	const std::vector<video::SColor> &getTile(const AlBigMapBlock &block);
	void invalidateView();
	void updateFollowCenter();
	// Draws the player position arrow (mirrors the minimap player marker).
	void drawPlayerMarker(video::IVideoDriver *driver, v2u32 target_size);
	// Draws minimap Lua markers (e.g. POI waypoints) on the map, with names.
	void drawWaypointMarkers(video::IVideoDriver *driver, v2u32 target_size);
	// Draws the status readout, first-open hints and the re-follow button.
	void drawStatusOverlay(video::IVideoDriver *driver, v2u32 target_size);

	// On-screen "re-follow player" button rect (screen pixels, anchored to
	// the top-right corner of `target_size`).
	static core::rect<s32> followButtonRect(v2u32 target_size);

	Client *m_client;
	std::string m_save_dir;
	std::string m_last_load_dir;
	bool m_save_enabled = true;
	bool m_save_dir_resolved = false;

	// View state.
	bool m_open = false;
	bool m_follow_player = true;
	v2s32 m_center = v2s32(0, 0);
	float m_zoom = 1.0f;
	// Follow-player bookkeeping so pan/zoom doesn't fight with the player.
	bool m_user_panned = false;

	// Blocks (keyed by full 3D block pos so multiple Y levels merge correctly).
	std::map<v3s16, std::unique_ptr<AlBigMapBlock>> m_blocks;
	// Blocks with unsaved changes since the last flush.
	std::set<v3s16> m_dirty;

	// 16x16 color tiles per block, derived from the current nodedef.
	std::map<v3s16, std::vector<video::SColor>> m_tiles;

	// Rendered view image/texture cache.
	video::IImage *m_view_image = nullptr;
	video::ITexture *m_view_texture = nullptr;
	v2u32 m_view_size = v2u32(0, 0);
	v2s32 m_last_view_center = v2s32(0, 0);
	bool m_view_dirty = true;

	// Player position marker (rotated quad, like the minimap's player arrow).
	irr_ptr<scene::SMeshBuffer> m_marker_buffer;
	video::ITexture *m_player_marker_texture = nullptr;

	// Input bookkeeping.
	bool m_left_down = false;
	v2s32 m_last_mouse = v2s32(0, 0);
	// Press-tracking for the re-follow button: a press inside the button rect
	// suppresses panning for its whole duration, and the toggle fires when the
	// release also stays inside the rect (m_click_candidate).
	bool m_click_candidate = false;
	bool m_press_in_button = false;
	bool m_key_was_down = false;
	bool m_cursor_was_visible = true;
	// Seconds the map has been open (drives the first-open hints overlay).
	float m_open_time = 0.0f;
	// Sequence number for unique rendered-section filenames.
	u32 m_image_seq = 0;
	// Dirty-block write budget used in step().
	static const size_t MAX_WRITES_PER_STEP = 128;
};
