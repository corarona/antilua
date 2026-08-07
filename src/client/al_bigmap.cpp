// Antilua — per-server minimap persistence + client-side "big map"
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client/al_bigmap.h"
#include "client/client.h"
#include "client/minimap.h"
#include "client/inputhandler.h"
#include "client/keys.h"
#include "client/localplayer.h"
#include "client/node_visuals.h"
#include "client/renderingengine.h"
#include "client/texturesource.h"
#include "client/fontengine.h"
#include "client/texturepaths.h"
#include "database/database-sqlite3.h"
#include "database/database.h"
#include "nodedef.h"
#include "mapnode.h"
#include "constants.h"
#include "util/numeric.h"
#include "util/serialize.h"
#include "filesys.h"
#include "porting.h"
#include "settings.h"
#include "log.h"
#include "util/string.h"

#include <IImage.h>
#include <ITexture.h>
#include <IVideoDriver.h>
#include <IrrlichtDevice.h>
#include <IGUIFont.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <unordered_map>

// File format magic: "ALB1"
static const u32 AL_BIGMAP_MAGIC = 0x414C4231u;
static const u8 AL_BIGMAP_VERSION = 1;
static const s32 MAX_INTERNAL_VIEW_SIZE = 2048;
static const size_t AL_BIGMAP_MAX_BLOCKS_DEFAULT = 100000;

// --- SQLite backend ------------------------------------------------------
// The per-server minimap persistence lives in a single `bigmap.sqlite` with
// one row per 16x16 block (position key + self-contained BLOB). This mirrors
// the map database's layout, so the Database_SQLite3 helpers apply directly.

#define AL_SQLRES(s, r, m) sqlite3_vrfy(s, m, r);
#define AL_SQLOK(s, m) AL_SQLRES(s, SQLITE_OK, m)
#define AL_PREPARE(name, query) \
	AL_SQLOK(sqlite3_prepare_v2(m_database, query, -1, &m_stmt_##name, NULL), \
		std::string("Failed to prepare query \"").append(query).append("\""))
#define AL_FINALIZE(name) \
	sqlite3_finalize(m_stmt_##name); \
	m_stmt_##name = nullptr;

class BigMapDatabaseSQLite3 : private Database_SQLite3, public MapDatabase
{
public:
	BigMapDatabaseSQLite3(const std::string &savedir) :
		Database_SQLite3(savedir, "bigmap") {}
	~BigMapDatabaseSQLite3() override
	{
		AL_FINALIZE(read)
		AL_FINALIZE(write)
		AL_FINALIZE(list)
		AL_FINALIZE(list_all)
		AL_FINALIZE(delete)
	}

	bool saveBlock(const v3s16 &pos, std::string_view data) override
	{
		verifyDatabase();
		int col = bindPos(m_stmt_write, pos);
		blob_to_sqlite(m_stmt_write, col, data);
		AL_SQLRES(sqlite3_step(m_stmt_write), SQLITE_DONE, "Failed to save block")
		sqlite3_reset(m_stmt_write);
		return true;
	}

	void loadBlock(const v3s16 &pos, std::string *block) override
	{
		verifyDatabase();
		bindPos(m_stmt_read, pos);
		if (sqlite3_step(m_stmt_read) != SQLITE_ROW) {
			block->clear();
			sqlite3_reset(m_stmt_read);
			return;
		}
		auto data = sqlite_to_blob(m_stmt_read, 0);
		block->assign(data);
		sqlite3_reset(m_stmt_read);
	}

	bool deleteBlock(const v3s16 &pos) override
	{
		verifyDatabase();
		bindPos(m_stmt_delete, pos);
		bool good = sqlite3_step(m_stmt_delete) == SQLITE_DONE;
		sqlite3_reset(m_stmt_delete);
		return good;
	}

	void listAllLoadableBlocks(std::vector<v3s16> &dst) override
	{
		verifyDatabase();
		while (sqlite3_step(m_stmt_list) == SQLITE_ROW) {
			dst.emplace_back(sqlite_to_int(m_stmt_list, 0),
					sqlite_to_int(m_stmt_list, 1),
					sqlite_to_int(m_stmt_list, 2));
		}
		sqlite3_reset(m_stmt_list);
	}

	// One sequential scan instead of a per-row SELECT (much faster when
	// loading a large map).
	void loadAllBlocks(
			std::vector<std::pair<v3s16, std::string>> &dst)
	{
		verifyDatabase();
		while (sqlite3_step(m_stmt_list_all) == SQLITE_ROW) {
			v3s16 pos(sqlite_to_int(m_stmt_list_all, 0),
					sqlite_to_int(m_stmt_list_all, 1),
					sqlite_to_int(m_stmt_list_all, 2));
			auto data = sqlite_to_blob(m_stmt_list_all, 3);
			dst.emplace_back(pos, std::string(data));
		}
		sqlite3_reset(m_stmt_list_all);
	}

	void beginSave() override { Database_SQLite3::beginSave(); }
	void endSave() override { Database_SQLite3::endSave(); }
	void verifyDatabase() override { Database_SQLite3::verifyDatabase(); }
	bool initialized() const override { return Database_SQLite3::initialized(); }

protected:
	void createDatabase() override
	{
		assert(m_database);
		const char *schema =
			"CREATE TABLE IF NOT EXISTS `blocks` (\n"
				"`x` INTEGER,"
				"`y` INTEGER,"
				"`z` INTEGER,"
				"`data` BLOB NOT NULL,"
				"PRIMARY KEY (`x`, `z`, `y`)"
			");\n";
		AL_SQLOK(sqlite3_exec(m_database, schema, NULL, NULL, NULL),
			"Failed to create database table");
	}

	void initStatements() override
	{
		assert(checkTable("blocks"));
		AL_PREPARE(read, "SELECT `data` FROM `blocks` WHERE `x` = ? AND `y` = ? AND `z` = ? LIMIT 1");
		AL_PREPARE(write, "REPLACE INTO `blocks` (`x`, `y`, `z`, `data`) VALUES (?, ?, ?, ?)");
		AL_PREPARE(delete, "DELETE FROM `blocks` WHERE `x` = ? AND `y` = ? AND `z` = ?");
		AL_PREPARE(list, "SELECT `x`, `y`, `z` FROM `blocks`");
		AL_PREPARE(list_all, "SELECT `x`, `y`, `z`, `data` FROM `blocks`");
	}

private:
	int bindPos(sqlite3_stmt *stmt, v3s16 pos, int index = 1)
	{
		int_to_sqlite(stmt, index, pos.X);
		int_to_sqlite(stmt, index + 1, pos.Y);
		int_to_sqlite(stmt, index + 2, pos.Z);
		return index + 3;
	}

	sqlite3_stmt *m_stmt_read = nullptr;
	sqlite3_stmt *m_stmt_write = nullptr;
	sqlite3_stmt *m_stmt_list = nullptr;
	sqlite3_stmt *m_stmt_list_all = nullptr;
	sqlite3_stmt *m_stmt_delete = nullptr;
};

#undef AL_SQLRES
#undef AL_SQLOK
#undef AL_PREPARE
#undef AL_FINALIZE

static v2u32 renderTargetSize()
{
	auto *driver = RenderingEngine::get_video_driver();
	if (!driver)
		return v2u32(0, 0);
	return driver->getCurrentRenderTargetSize();
}

AlBigMap *AlBigMap::s_active = nullptr;

// Floor division that is safe for s32 values beyond the s16 range used by
// getContainerPos().
static s32 floorDiv(s32 a, s32 b)
{
	s32 q = a / b;
	s32 r = a % b;
	if (r != 0 && ((r < 0) != (b < 0)))
		q -= 1;
	return q;
}

static v3s16 nodeToBlock(s32 x, s32 z)
{
	return v3s16(floorDiv(x, MAP_BLOCKSIZE), 0,
			floorDiv(z, MAP_BLOCKSIZE));
}

// Unit quad (-1..1) used for the player position arrow. Geometry and UVs
// mirror the minimap's marker quad so the arrow renders with the same
// orientation as on the minimap.
static irr_ptr<scene::SMeshBuffer> createMarkerMeshBuffer()
{
	auto buf = make_irr<scene::SMeshBuffer>();
	auto &vertices = buf->Vertices->Data;
	auto &indices = buf->Indices->Data;
	vertices.resize(4);
	indices.resize(6);
	static const video::SColor c(255, 255, 255, 255);

	vertices[0] = video::S3DVertex(-1, -1, 0, 0, 0, 1, c, 0, 1);
	vertices[1] = video::S3DVertex(-1,  1, 0, 0, 0, 1, c, 0, 0);
	vertices[2] = video::S3DVertex( 1,  1, 0, 0, 0, 1, c, 1, 0);
	vertices[3] = video::S3DVertex( 1, -1, 0, 0, 0, 1, c, 1, 1);

	indices[0] = 0;
	indices[1] = 1;
	indices[2] = 2;
	indices[3] = 2;
	indices[4] = 3;
	indices[5] = 0;

	buf->setHardwareMappingHint(scene::EHM_STATIC);
	return buf;
}

AlBigMap::AlBigMap(Client *client) :
	m_client(client)
{
	m_save_enabled = g_settings->getBool("enable_minimap_saving");
	m_marker_buffer = createMarkerMeshBuffer();
}

AlBigMap::~AlBigMap()
{
	if (m_view_image)
		m_view_image->drop();
	if (m_view_texture) {
		auto *driver = RenderingEngine::get_video_driver();
		if (driver)
			driver->removeTexture(m_view_texture);
	}
	m_marker_buffer.reset();
	if (s_active == this)
		s_active = nullptr;
}

AlBigMap *AlBigMap::getActive()
{
	return s_active;
}

void AlBigMap::closeActive()
{
	if (s_active)
		s_active->close();
}

std::string AlBigMap::resolveSaveDir() const
{
	if (m_client->isSingleplayer()) {
		const std::string &world_path = m_client->getWorldPath();
		if (world_path.empty())
			return "";
		return world_path + DIR_DELIM "minimap";
	}

	std::string addr = m_client->getAddressName();
	if (addr.empty())
		return "";
	std::string server_id = addr + "_" + std::to_string(m_client->getServerAddress().getPort());
	std::string clean = fs::AbsolutePath(porting::path_user + DIR_DELIM "data"
			+ DIR_DELIM "server" + DIR_DELIM + server_id);
	return clean + DIR_DELIM "minimap";
}

std::string AlBigMap::getSaveDir() const
{
	return m_save_dir;
}

std::string AlBigMap::getBlocksDir() const
{
	return m_save_dir.empty() ? "" : m_save_dir + DIR_DELIM "blocks";
}

std::string AlBigMap::getImagesDir() const
{
	return m_save_dir.empty() ? "" : m_save_dir + DIR_DELIM "images";
}

void AlBigMap::onConnect()
{
	m_save_dir = resolveSaveDir();
	m_save_dir_resolved = !m_save_dir.empty();
	m_save_enabled = g_settings->getBool("enable_minimap_saving");
	m_center = v2s32(0, 0);
	m_follow_player = true;
	m_user_panned = false;
	m_key_was_down = false;
	invalidateView();

	// Make the rendered-section image directory resolvable as a texture, so
	// formspec image elements can reference section PNGs by filename (same
	// mechanism as the per-server poi screenshot directory).
	if (!m_save_dir.empty()) {
		registerTextureSearchDir(getImagesDir());
		fs::CreateAllDirs(getImagesDir());
	}

	// Loading needs the nodedef (for content-id remap), which is received
	// during content transfer. If it's not ready yet, step() retries.
	if (m_client->isNodedefReceived())
		load();
}

void AlBigMap::onDisconnect()
{
	save(); // flush pending writes
	close();
	m_blocks.clear();
	m_tiles.clear();
	m_dirty.clear();
	m_save_dir.clear();
	m_save_dir_resolved = false;
	// Reset the load marker so reconnecting to the same server in this
	// session reloads the persisted blocks (previously they were skipped,
	// leaving the map empty until a full restart).
	m_last_load_dir.clear();
	m_db.reset();
	invalidateView();
}

void AlBigMap::onBlockAdded(v3s16 pos, const MinimapMapblock *data)
{
	if (!m_save_enabled)
		return;

	auto block = std::make_unique<AlBigMapBlock>();
	block->pos = pos;
	block->pixels.resize(MAP_BLOCKSIZE * MAP_BLOCKSIZE);

	for (size_t i = 0; i < MAP_BLOCKSIZE * MAP_BLOCKSIZE; i++) {
		const MinimapPixel &pix = data->data[i];
		AlBigMapPixel &out = block->pixels[i];
		out.param0 = pix.n.getContent();
		out.param1 = pix.n.getParam1();
		out.param2 = pix.n.getParam2();
		out.height = pix.height;
		out.air_count = pix.air_count;

		// Record the node name for this content id (self-contained remap info).
		if (out.param0 != CONTENT_AIR && out.param0 != CONTENT_IGNORE
				&& out.param0 != CONTENT_UNKNOWN) {
			const NodeDefManager *ndef = m_client->getNodeDefManager();
			if (ndef && block->name_map.find(out.param0) == block->name_map.end()) {
				const std::string &name = ndef->get(out.param0).name;
				if (!name.empty())
					block->name_map[out.param0] = name;
			}
		}
	}

	m_blocks[pos] = std::move(block);
	m_dirty.insert(pos);
	m_tiles.erase(pos);
	invalidateView();
}

int AlBigMap::step(float dtime)
{
	int result = 0;
	if (m_open)
		m_open_time += dtime;

	// Deferred load: waits for the nodedef (content transfer) to finish.
	if (m_save_dir_resolved && !m_save_dir.empty()
			&& m_last_load_dir != m_save_dir
			&& m_client->isNodedefReceived())
		load();

	if (m_save_enabled && !m_dirty.empty()) {
		if (!m_db)
			openDb();
		if (m_db) {
			// Flush a bounded number of dirty blocks per step to spread IO
			// cost, batched in a single transaction.
			m_db->beginSave();
			size_t n = 0;
			while (!m_dirty.empty() && n < MAX_WRITES_PER_STEP) {
				v3s16 pos = *m_dirty.begin();
				m_dirty.erase(m_dirty.begin());
				auto it = m_blocks.find(pos);
				if (it != m_blocks.end()) {
					m_db->saveBlock(pos, serializeBlock(*it->second));
					n++;
				}
			}
			m_db->endSave();
		}
	}

	// Input handling (only relevant while connected to a world).
	IrrlichtDevice *device = RenderingEngine::get_raw_device();
	if (!device || !m_save_dir_resolved)
		return result;

	auto *receiver = dynamic_cast<MyEventReceiver *>(device->getEventReceiver());
	auto *cur = device->getCursorControl();
	if (!receiver)
		return result;

	bool key_down = receiver->IsKeyDown(KeyType::BIG_MAP);
	if (key_down && !m_key_was_down) {
		if (m_open) {
			close();
			result = 2;
		} else {
			open();
			result = 1;
		}
	}
	m_key_was_down = key_down;

	if (!m_open)
		return result;

	s32 wheel = receiver->getMouseWheel();
	if (wheel != 0) {
		if (m_open_time < 6.0f)
			m_open_time = 6.0f; // dismiss the first-open hints on interaction
		m_zoom = std::clamp(m_zoom * (wheel > 0 ? 1.25f : 0.8f), 0.1f, 16.0f);
		invalidateView();
	}

	if (cur) {
		v2s32 mp = cur->getPosition();
		bool dragging = receiver->IsKeyDown(KeyType::DIG);

		// Re-follow button handling. A press that starts inside the button
		// rect pans nothing (the button owns that drag); the toggle fires if
		// the release also stays inside the rect.
		if (dragging && !m_left_down) {
			m_left_down = true;
			m_press_in_button = followButtonRect(renderTargetSize()).isPointInside(mp);
			m_click_candidate = m_press_in_button;
		} else if (!dragging && m_left_down) {
			m_left_down = false;
			if (m_click_candidate) {
				m_click_candidate = false;
				if (followButtonRect(renderTargetSize()).isPointInside(mp)) {
					setFollowPlayer(!m_follow_player);
					if (m_follow_player) {
						updateFollowCenter();
						m_user_panned = false;
					}
					invalidateView();
				}
			}
			m_press_in_button = false;
		} else if (dragging && m_click_candidate) {
			// Drag: cancel the toggle if the cursor leaves the button.
			if (!followButtonRect(renderTargetSize()).isPointInside(mp))
				m_click_candidate = false;
		}

		// Panning is suppressed while the press is owned by the button.
		if (dragging && !m_press_in_button && m_last_mouse != v2s32(0, 0)) {
			v2s32 delta = mp - m_last_mouse;
			if (delta != v2s32(0, 0)) {
				if (m_open_time < 6.0f)
					m_open_time = 6.0f; // dismiss the first-open hints on interaction
				m_follow_player = false;
				m_user_panned = true;
				m_center.X -= (s32)std::round((f32)delta.X / m_zoom);
				// Vertical axis is inverted so dragging down pulls the map
				// content down (grab behavior), matching the horizontal axis.
				m_center.Y += (s32)std::round((f32)delta.Y / m_zoom);
				invalidateView();
			}
		}
		m_last_mouse = mp;
	}

	return result;
}

void AlBigMap::open()
{
	m_open = true;
	m_open_time = 0.0f;
	s_active = this;
	m_user_panned = false;
	if (!m_follow_player)
		m_follow_player = true;
	auto *device = RenderingEngine::get_raw_device();
	if (device) {
		if (auto *cur = device->getCursorControl()) {
			m_cursor_was_visible = cur->isVisible();
			cur->setVisible(true);
		}
	}
	invalidateView();
}

void AlBigMap::close()
{
	m_open = false;
	if (s_active == this)
		s_active = nullptr;
	m_left_down = false;
	m_click_candidate = false;
	m_press_in_button = false;
	auto *device = RenderingEngine::get_raw_device();
	if (device) {
		if (auto *cur = device->getCursorControl())
			cur->setVisible(m_cursor_was_visible);
	}
}

void AlBigMap::setCenterNode(v2s32 c)
{
	m_center = c;
	invalidateView();
}

void AlBigMap::pan(v2s32 delta_nodes)
{
	m_center += delta_nodes;
	m_follow_player = false;
	m_user_panned = true;
	invalidateView();
}

void AlBigMap::setZoom(float z)
{
	m_zoom = std::clamp(z, 0.1f, 16.0f);
	invalidateView();
}

void AlBigMap::invalidateView()
{
	m_view_dirty = true;
}

void AlBigMap::updateFollowCenter()
{
	if (!m_follow_player)
		return;
	LocalPlayer *player = m_client->getEnv().getLocalPlayer();
	if (!player)
		return;
	v3f pos = player->getPosition() / BS;
	m_center = v2s32((s32)std::floor(pos.X), (s32)std::floor(pos.Z));
}

size_t AlBigMap::getBlockCount() const
{
	return m_blocks.size();
}

bool AlBigMap::hasBlock(v3s16 block_pos) const
{
	return m_blocks.find(block_pos) != m_blocks.end();
}

void AlBigMap::getCoverage(v3s16 *min_pos, v3s16 *max_pos) const
{
	*min_pos = v3s16(0, 0, 0);
	*max_pos = v3s16(0, 0, 0);
	bool first = true;
	for (const auto &kv : m_blocks) {
		if (first) {
			*min_pos = kv.first;
			*max_pos = kv.first;
			first = false;
			continue;
		}
		min_pos->X = std::min(min_pos->X, kv.first.X);
		min_pos->Z = std::min(min_pos->Z, kv.first.Z);
		max_pos->X = std::max(max_pos->X, kv.first.X);
		max_pos->Z = std::max(max_pos->Z, kv.first.Z);
	}
}

bool AlBigMap::getBlock(v3s16 block_pos, AlBigMapBlock **out) const
{
	auto it = m_blocks.find(block_pos);
	if (it == m_blocks.end())
		return false;
	if (out)
		*out = it->second.get();
	return true;
}

bool AlBigMap::getPixel(v2s32 node_pos, std::string *name, u8 *param2,
		u16 *height, u16 *air_count) const
{
	v3s16 bp = nodeToBlock(node_pos.X, node_pos.Y);
	s32 node_min_x = bp.X * MAP_BLOCKSIZE;
	s32 node_min_z = bp.Z * MAP_BLOCKSIZE;

	// Find the tallest non-air pixel across all Y blocks in this column.
	int best_height = -32768;
	const AlBigMapPixel *best = nullptr;
	for (const auto &kv : m_blocks) {
		if (kv.first.X != bp.X || kv.first.Z != bp.Z)
			continue;
		s32 ix = node_pos.X - node_min_x;
		s32 iz = node_pos.Y - node_min_z;
		if (ix < 0 || iz < 0 || ix >= MAP_BLOCKSIZE || iz >= MAP_BLOCKSIZE)
			continue;
		const AlBigMapPixel &p = kv.second->pixels[iz * MAP_BLOCKSIZE + ix];
		if (p.param0 == CONTENT_AIR)
			continue;
		s32 h_abs = kv.first.Y * MAP_BLOCKSIZE + p.height;
		if (h_abs > best_height) {
			best_height = h_abs;
			best = &p;
		}
	}

	if (!best)
		return false;

	if (name) {
		const NodeDefManager *ndef = m_client->getNodeDefManager();
		if (ndef)
			*name = ndef->get(best->param0).name;
		else
			name->clear();
	}
	if (param2)
		*param2 = best->param2;
	if (height)
		*height = best->height;
	if (air_count)
		*air_count = best->air_count;
	return true;
}

bool AlBigMap::setPixel(v2s32 node_pos, const std::string &name,
		u16 height, u16 air_count, u8 param2)
{
	const NodeDefManager *ndef = m_client->getNodeDefManager();
	if (!ndef)
		return false;
	content_t id = ndef->getId(name);
	if (id == CONTENT_IGNORE || id == CONTENT_UNKNOWN)
		return false;

	v3s16 bp = nodeToBlock(node_pos.X, node_pos.Y);
	auto it = m_blocks.find(bp);
	if (it == m_blocks.end()) {
		auto block = std::make_unique<AlBigMapBlock>();
		block->pos = bp;
		block->pixels.assign(MAP_BLOCKSIZE * MAP_BLOCKSIZE, AlBigMapPixel{});
		for (auto &p : block->pixels) {
			p.param0 = CONTENT_AIR;
			p.param1 = 0;
			p.param2 = 0;
			p.height = 0;
			p.air_count = 0;
		}
		it = m_blocks.emplace(bp, std::move(block)).first;
	}

	s32 ix = node_pos.X - bp.X * MAP_BLOCKSIZE;
	s32 iz = node_pos.Y - bp.Z * MAP_BLOCKSIZE;
	if (ix < 0 || iz < 0 || ix >= MAP_BLOCKSIZE || iz >= MAP_BLOCKSIZE)
		return false;

	AlBigMapPixel &p = it->second->pixels[iz * MAP_BLOCKSIZE + ix];
	p.param0 = id;
	p.param1 = 0;
	p.param2 = param2;
	p.height = height;
	p.air_count = air_count;
	if (it->second->name_map.find(id) == it->second->name_map.end()) {
		const std::string &n = ndef->get(id).name;
		if (!n.empty())
			it->second->name_map[id] = n;
	}

	m_dirty.insert(bp);
	m_tiles.erase(bp);
	invalidateView();
	return true;
}

std::string AlBigMap::serializeBlock(const AlBigMapBlock &block) const
{
	std::ostringstream os(std::ios::binary);
	writeU32(os, AL_BIGMAP_MAGIC);
	writeU8(os, AL_BIGMAP_VERSION);
	writeS16(os, block.pos.X);
	writeS16(os, block.pos.Y);
	writeS16(os, block.pos.Z);
	writeU16(os, block.name_map.size());
	for (const auto &kv : block.name_map) {
		writeU16(os, kv.first);
		os << serializeString16(kv.second);
	}
	for (const AlBigMapPixel &p : block.pixels) {
		writeU16(os, p.param0);
		writeU8(os, p.param1);
		writeU8(os, p.param2);
		writeU16(os, p.height);
		writeU16(os, p.air_count);
	}
	return os.str();
}

bool AlBigMap::deserializeBlock(const std::string &data,
		AlBigMapBlock &block) const
{
	// Fast cursor over the serialized bytes (avoids istringstream overhead,
	// which dominates when loading hundreds of thousands of blocks).
	const char *p = data.data();
	const char *end = p + data.size();
	auto need = [&](size_t n) {
		if ((size_t)(end - p) < n)
			throw SerializationError("AlBigMap block truncated");
	};
	auto rd_u8 = [&]() {
		need(1);
		return (u8)*p++;
	};
	auto rd_u16 = [&]() {
		need(2);
		u16 v = ((u8)p[0] << 8) | (u8)p[1];
		p += 2;
		return v;
	};
	auto rd_u32 = [&]() {
		need(4);
		u32 v = ((u8)p[0] << 24) | ((u8)p[1] << 16)
				| ((u8)p[2] << 8) | (u8)p[3];
		p += 4;
		return v;
	};
	auto rd_s16 = [&]() { return (s16)rd_u16(); };
	try {
		if (rd_u32() != AL_BIGMAP_MAGIC || rd_u8() != AL_BIGMAP_VERSION)
			return false;
		block.pos.X = rd_s16();
		block.pos.Y = rd_s16();
		block.pos.Z = rd_s16();
		u16 n = rd_u16();
		block.name_map.clear();
		for (u16 i = 0; i < n; i++) {
			u16 id = rd_u16();
			u16 len = rd_u16();
			need(len);
			std::string name(p, len);
			p += len;
			block.name_map[id] = name;
		}
		block.pixels.resize(MAP_BLOCKSIZE * MAP_BLOCKSIZE);
		for (size_t i = 0; i < block.pixels.size(); i++) {
			AlBigMapPixel &px = block.pixels[i];
			px.param0 = rd_u16();
			px.param1 = rd_u8();
			px.param2 = rd_u8();
			px.height = rd_u16();
			px.air_count = rd_u16();
		}
		return true;
	} catch (SerializationError &e) {
		errorstream << "AlBigMap: failed to parse block data: " << e.what()
				<< std::endl;
		return false;
	}
}

void AlBigMap::openDb()
{
	if (m_db)
		return;
	if (m_save_dir.empty())
		return;
	m_db = std::make_unique<BigMapDatabaseSQLite3>(m_save_dir);
	m_db->verifyDatabase();
}

void AlBigMap::migrateOldBlocks()
{
	std::string dir = getBlocksDir();
	if (dir.empty() || !fs::PathExists(dir))
		return;

	// Only bother when there are per-file blocks to convert.
	bool any = false;
	for (const auto &entry : fs::GetDirListing(dir)) {
		if (entry.dir)
			continue;
		if (entry.name.size() < 5
				|| entry.name.compare(entry.name.size() - 4, 4, ".bin") != 0)
			continue;
		any = true;
		break;
	}
	if (!any)
		return;

	actionstream << "AlBigMap: migrating old per-block files to sqlite..."
			<< std::endl;
	openDb();
	if (!m_db)
		return;

	m_db->beginSave();
	for (const auto &entry : fs::GetDirListing(dir)) {
		if (entry.dir)
			continue;
		const std::string &fname = entry.name;
		if (fname.size() < 5
				|| fname.compare(fname.size() - 4, 4, ".bin") != 0)
			continue;
		std::string path = dir;
		path += DIR_DELIM;
		path += fname;
		std::ifstream is(path, std::ios::binary);
		if (!is.good())
			continue;
		std::string data((std::istreambuf_iterator<char>(is)),
				std::istreambuf_iterator<char>());
		AlBigMapBlock block;
		if (deserializeBlock(data, block))
			m_db->saveBlock(block.pos, data);
	}
	m_db->endSave();
	actionstream << "AlBigMap: migrated old block files, removing them"
			<< std::endl;
	fs::RecursiveDelete(dir);
}

void AlBigMap::load()
{
	if (m_save_dir.empty())
		return;
	m_last_load_dir = m_save_dir;

	// Nothing to load if neither the sqlite database nor the old per-file
	// format exists.
	if (!fs::PathExists(m_save_dir + DIR_DELIM "bigmap.sqlite")
			&& !fs::PathExists(getBlocksDir()))
		return;

	openDb();
	if (!m_db || !m_db->initialized())
		return;

	// Import and remove any leftover per-file-format blocks.
	migrateOldBlocks();

	const NodeDefManager *ndef = m_client->getNodeDefManager();
	std::vector<std::pair<v3s16, std::string>> rows;
	m_db->loadAllBlocks(rows);
	if (rows.empty())
		return;

	std::vector<AlBigMapBlock> loaded;
	loaded.reserve(rows.size());
	for (auto &row : rows) {
		AlBigMapBlock block;
		if (deserializeBlock(row.second, block))
			loaded.push_back(std::move(block));
	}

	if (loaded.empty())
		return;

	size_t cap = g_settings->getU32("minimap_save_max_blocks");
	if (cap == 0)
		cap = AL_BIGMAP_MAX_BLOCKS_DEFAULT;

	// Saved content ids are server-consistent, so a single cache maps them to
	// the current session's ids instead of re-resolving the node name for
	// every pixel (which is the hot path when loading many blocks).
	std::unordered_map<u16, content_t> id_cache;
	// Mirror cache for the rebuilt name maps (id -> current node name).
	std::unordered_map<content_t, std::string> name_cache;

	for (auto &block : loaded) {
		// Remap saved content ids to the current session's nodedef.
		for (AlBigMapPixel &p : block.pixels) {
			u16 id = p.param0;
			if (id == CONTENT_AIR || id == CONTENT_IGNORE || id == CONTENT_UNKNOWN)
				continue;
			auto cit = id_cache.find(id);
			if (cit == id_cache.end()) {
				auto it = block.name_map.find(id);
				content_t new_id = CONTENT_UNKNOWN;
				if (it != block.name_map.end()) {
					content_t resolved = ndef->getId(it->second);
					if (resolved != CONTENT_IGNORE && resolved != CONTENT_UNKNOWN)
						new_id = resolved;
				}
				id_cache[id] = new_id;
				p.param0 = new_id;
			} else {
				p.param0 = cit->second;
			}
		}
		// Refresh the name map to the current ids (for future saves).
		block.name_map.clear();
		for (const AlBigMapPixel &p : block.pixels) {
			if (p.param0 == CONTENT_AIR || p.param0 == CONTENT_IGNORE
					|| p.param0 == CONTENT_UNKNOWN)
				continue;
			if (block.name_map.find(p.param0) == block.name_map.end()) {
				auto nit = name_cache.find(p.param0);
				if (nit == name_cache.end()) {
					std::string n = ndef->get(p.param0).name;
					nit = name_cache.emplace(p.param0, std::move(n)).first;
				}
				block.name_map[p.param0] = nit->second;
			}
		}
		if (m_blocks.find(block.pos) == m_blocks.end())
			m_blocks[block.pos] = std::make_unique<AlBigMapBlock>(std::move(block));
	}

	// Enforce the block cap: drop the blocks farthest from the player first,
	// so the explored area around the current position survives.
	if (m_blocks.size() > cap) {
		size_t excess = m_blocks.size() - cap;
		s64 pxl = 0;
		s64 pzl = 0;
		const LocalPlayer *player = m_client->getEnv().getLocalPlayer();
		if (player) {
			v3f pp = player->getPosition() / BS;
			pxl = (s64)std::floor(pp.X);
			pzl = (s64)std::floor(pp.Z);
		}
		std::vector<v3s16> farthest;
		farthest.reserve(excess + 1);
		for (const auto &kv : m_blocks)
			farthest.push_back(kv.first);
		std::partial_sort(farthest.begin(), farthest.begin() + excess,
				farthest.end(), [pxl, pzl](const v3s16 &a, const v3s16 &b) {
			s64 ax = (s64)a.X * MAP_BLOCKSIZE + MAP_BLOCKSIZE / 2 - pxl;
			s64 az = (s64)a.Z * MAP_BLOCKSIZE + MAP_BLOCKSIZE / 2 - pzl;
			s64 bx = (s64)b.X * MAP_BLOCKSIZE + MAP_BLOCKSIZE / 2 - pxl;
			s64 bz = (s64)b.Z * MAP_BLOCKSIZE + MAP_BLOCKSIZE / 2 - pzl;
			return ax * ax + az * az > bx * bx + bz * bz;
		});
		for (size_t i = 0; i < excess; i++) {
			m_blocks.erase(farthest[i]);
			m_dirty.erase(farthest[i]);
			m_tiles.erase(farthest[i]);
		}
	}

	invalidateView();
	actionstream << "AlBigMap: loaded " << loaded.size()
			<< " minimap blocks for this server" << std::endl;
}

void AlBigMap::save()
{
	if (m_save_dir.empty() || m_dirty.empty())
		return;
	if (!m_db)
		openDb();
	if (!m_db)
		return;
	m_db->beginSave();
	for (v3s16 pos : m_dirty) {
		auto it = m_blocks.find(pos);
		if (it != m_blocks.end())
			m_db->saveBlock(pos, serializeBlock(*it->second));
	}
	m_db->endSave();
	m_dirty.clear();
}

void AlBigMap::clear()
{
	m_blocks.clear();
	m_tiles.clear();
	m_dirty.clear();
	invalidateView();
	if (m_save_dir.empty())
		return;
	// Close and delete the database, plus any leftover per-file blocks.
	m_db.reset();
	std::string db_path = m_save_dir + DIR_DELIM "bigmap.sqlite";
	if (fs::PathExists(db_path))
		fs::DeleteSingleFileOrEmptyDirectory(db_path, false);
	std::string dir = m_save_dir + DIR_DELIM "blocks";
	if (fs::PathExists(dir))
		fs::RecursiveDelete(dir);
}

video::SColor AlBigMap::pixelColor(const AlBigMapBlock &block, size_t idx) const
{
	const AlBigMapPixel &p = block.pixels[idx];
	const NodeDefManager *ndef = m_client->getNodeDefManager();
	video::SColor tilecolor(240, 0, 0, 0);
	if (!ndef)
		return tilecolor;

	const ContentFeatures &f = ndef->get(p.param0);
	const auto &tile = f.tiledef[0];
	const auto &overlay = f.tiledef_overlay[0];

	if (!overlay.name.empty() && overlay.has_color) {
		tilecolor = overlay.color;
	} else if (overlay.name.empty() && tile.has_color) {
		tilecolor = tile.color;
	} else if (f.visuals) {
		f.visuals->getColor(p.param2, &tilecolor);
	}
	if (f.visuals) {
		const video::SColor &minimap_color = f.visuals->minimap_color;
		tilecolor.setRed(tilecolor.getRed() * minimap_color.getRed() / 255);
		tilecolor.setGreen(tilecolor.getGreen() * minimap_color.getGreen() / 255);
		tilecolor.setBlue(tilecolor.getBlue() * minimap_color.getBlue() / 255);
	}
	tilecolor.setAlpha(255);
	return tilecolor;
}

const std::vector<video::SColor> &AlBigMap::getTile(const AlBigMapBlock &block)
{
	auto it = m_tiles.find(block.pos);
	if (it != m_tiles.end())
		return it->second;

	std::vector<video::SColor> tile;
	tile.resize(MAP_BLOCKSIZE * MAP_BLOCKSIZE);
	for (size_t i = 0; i < tile.size(); i++)
		tile[i] = pixelColor(block, i);
	auto res = m_tiles.emplace(block.pos, std::move(tile));
	return res.first->second;
}

void AlBigMap::draw(video::IVideoDriver *driver, v2u32 target_size)
{
	if (!m_open)
		return;

	if (m_view_image && m_view_size != target_size) {
		m_view_image->drop();
		m_view_image = nullptr;
		m_view_dirty = true;
	}
	if (!m_view_image) {
		m_view_image = driver->createImage(video::ECF_A8R8G8B8,
				core::dimension2du(target_size.X, target_size.Y));
		m_view_size = target_size;
		m_view_dirty = true;
	}

	// Re-rasterize when the view is dirty (new/cleared blocks, pan, zoom) or
	// when following the player across map data. With no saved blocks the
	// scrim is uniform, so only rasterize on an actual invalidation.
	bool need_raster = m_view_dirty;
	if (!m_blocks.empty() && m_follow_player
			&& m_center != m_last_view_center)
		need_raster = true;

	if (need_raster) {
		if (m_follow_player) {
			updateFollowCenter();
			m_view_dirty = true;
		}
		m_last_view_center = m_center;

		const u32 W = m_view_size.X;
		const u32 H = m_view_size.Y;
		const float zoom = m_zoom;
		const float cx = (f32)m_center.X;
		const float cz = (f32)m_center.Y;

		s32 nw = std::max(1, (s32)std::ceil((f32)W / zoom));
		s32 nh = std::max(1, (s32)std::ceil((f32)H / zoom));
		if (nw > MAX_INTERNAL_VIEW_SIZE || nh > MAX_INTERNAL_VIEW_SIZE) {
			float s = std::min((f32)MAX_INTERNAL_VIEW_SIZE / nw,
					(f32)MAX_INTERNAL_VIEW_SIZE / nh);
			nw = std::max(1, (s32)(nw * s));
			nh = std::max(1, (s32)(nh * s));
		}

		s32 node_min_x = (s32)std::floor(cx - nw / 2.0f);
		s32 node_min_z = (s32)std::floor(cz - nh / 2.0f);
		s32 node_max_x = node_min_x + nw - 1;
		s32 node_max_z = node_min_z + nh - 1;
		s32 bx_min = floorDiv(node_min_x, MAP_BLOCKSIZE);
		s32 bx_max = floorDiv(node_max_x, MAP_BLOCKSIZE);
		s32 bz_min = floorDiv(node_min_z, MAP_BLOCKSIZE);
		s32 bz_max = floorDiv(node_max_z, MAP_BLOCKSIZE);

		std::vector<s32> best((size_t)nw * nh, -32768);
		std::vector<video::SColor> colors((size_t)nw * nh);

		for (const auto &kv : m_blocks) {
			const v3s16 &bp = kv.first;
			if (bp.X < bx_min || bp.X > bx_max || bp.Z < bz_min || bp.Z > bz_max)
				continue;
			const AlBigMapBlock &block = *kv.second;
			const std::vector<video::SColor> &tile = getTile(block);
			s32 nx0 = bp.X * MAP_BLOCKSIZE;
			s32 nz0 = bp.Z * MAP_BLOCKSIZE;
			for (u8 z = 0; z < MAP_BLOCKSIZE; z++)
			for (u8 x = 0; x < MAP_BLOCKSIZE; x++) {
				size_t idx = z * MAP_BLOCKSIZE + x;
				if (block.pixels[idx].param0 == CONTENT_AIR)
					continue;
				s32 node_x = nx0 + x;
				s32 node_z = nz0 + z;
				s32 bxi = node_x - node_min_x;
				// Flip Z so +z (north) is at the top, matching the minimap.
				s32 bzi = node_max_z - node_z;
				if (bxi < 0 || bzi < 0 || bxi >= nw || bzi >= nh)
					continue;
				s32 h_abs = bp.Y * MAP_BLOCKSIZE + block.pixels[idx].height;
				size_t si = bzi * nw + bxi;
				if (h_abs > best[si]) {
					best[si] = h_abs;
					colors[si] = tile[idx];
				}
			}
		}

		video::IImage *internal = driver->createImage(video::ECF_A8R8G8B8,
				core::dimension2du(nw, nh));
		internal->fill(video::SColor(90, 0, 0, 0));
		for (s32 j = 0; j < nh; j++)
		for (s32 i = 0; i < nw; i++) {
			size_t si = j * nw + i;
			if (best[si] > -32768)
				internal->setPixel(i, j, colors[si]);
		}
		internal->copyToScaling(m_view_image);
		internal->drop();

		if (m_view_texture)
			driver->removeTexture(m_view_texture);
		m_view_texture = driver->addTexture("al_bigmap_view", m_view_image);
		m_view_dirty = false;
	}

	if (!m_view_texture)
		return;
	core::rect<s32> src(0, 0, m_view_size.X, m_view_size.Y);
	core::rect<s32> dst(0, 0, target_size.X, target_size.Y);
	driver->draw2DImage(m_view_texture, dst, src, nullptr, nullptr, true);

	drawPlayerMarker(driver, target_size);
	drawWaypointMarkers(driver, target_size);
	drawStatusOverlay(driver, target_size);
}

void AlBigMap::drawPlayerMarker(video::IVideoDriver *driver, v2u32 target_size)
{
	LocalPlayer *player = m_client->getEnv().getLocalPlayer();
	if (!player || !m_marker_buffer)
		return;

	// Player node position (same flooring as updateFollowCenter).
	v3f pos = player->getPosition() / BS;
	s32 px = (s32)std::floor(pos.X);
	s32 pz = (s32)std::floor(pos.Z);

	const f32 W = (f32)target_size.X;
	const f32 H = (f32)target_size.Y;
	if (W <= 0 || H <= 0)
		return;

	// Marker size (screen pixels).
	const f32 marker_size = 0.24f * std::min(W, H);

	// Screen position of the player using the same node->screen mapping as
	// the rasterize step (+z north is up on screen).
	f32 sx = ((f32)px - (f32)m_center.X) * m_zoom + W / 2.0f;
	f32 sz = ((f32)m_center.Y - (f32)pz) * m_zoom + H / 2.0f;

	// Skip when the marker is fully off-screen.
	if (sx < -marker_size || sx > W + marker_size
			|| sz < -marker_size || sz > H + marker_size)
		return;

	if (!m_player_marker_texture)
		m_player_marker_texture =
				m_client->getTextureSource()->getTexture("player_marker.png");
	if (!m_player_marker_texture)
		return;

	core::rect<s32> oldViewPort = driver->getViewPort();
	core::matrix4 oldProjMat = driver->getTransform(video::ETS_PROJECTION);
	core::matrix4 oldViewMat = driver->getTransform(video::ETS_VIEW);

	driver->setViewPort(core::rect<s32>(0, 0, target_size.X, target_size.Y));
	driver->setTransform(video::ETS_PROJECTION, core::matrix4());
	driver->setTransform(video::ETS_VIEW, core::matrix4());

	// World matrix: translate to the player's NDC position, rotate the arrow
	// to point in the facing direction, scale to the marker size. The arrow
	// renders pointing up when unrotated, so rotating it by the player's yaw
	// (degrees) makes it point at the world direction faced (north = +z up,
	// east = +x right). Order matters: the quad must be ROTATED in local
	// space first, then scaled (tr*scl*rot), otherwise the anisotropic
	// NDC->pixel mapping shears the marker on non-square screens.
	core::matrix4 rot;
	rot.setRotationDegrees(core::vector3df(0, 0, player->getYaw()));
	core::matrix4 scl;
	scl.setScale(core::vector3df(marker_size / W, marker_size / H, 1));
	core::matrix4 tr;
	tr.setTranslation(core::vector3df(
			sx * 2.0f / W - 1.0f, 1.0f - sz * 2.0f / H, 0));
	core::matrix4 matrix = tr * scl * rot;

	auto &material = m_marker_buffer->getMaterial();
	material.TextureLayers[0].Texture = m_player_marker_texture;
	material.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL;

	driver->setTransform(video::ETS_WORLD, matrix);
	driver->setMaterial(material);
	driver->drawMeshBuffer(m_marker_buffer.get());

	driver->setViewPort(oldViewPort);
	driver->setTransform(video::ETS_PROJECTION, oldProjMat);
	driver->setTransform(video::ETS_VIEW, oldViewMat);
}

void AlBigMap::drawWaypointMarkers(video::IVideoDriver *driver,
		v2u32 target_size)
{
	Minimap *minimap = m_client->getMinimap();
	if (!minimap)
		return;

	const f32 W = (f32)target_size.X;
	const f32 H = (f32)target_size.Y;
	if (W <= 0 || H <= 0)
		return;

	// Half-size of the marker dot (screen pixels).
	const f32 marker_size2 = 0.005f * std::min(W, H);

	gui::IGUIFont *font = g_fontengine ? g_fontengine->getFont() : nullptr;

	for (const MinimapLuaMarker &marker : minimap->getLuaMarkers()) {
		// Project to screen using the same north-up mapping as the rasterize
		// step; height is ignored, like on the minimap.
		f32 sx = ((f32)marker.world_pos.X - (f32)m_center.X) * m_zoom + W / 2.0f;
		f32 sz = ((f32)m_center.Y - (f32)marker.world_pos.Z) * m_zoom + H / 2.0f;

		// Rim-clamp far waypoints to the inset screen edge so they stay
		// visible as navigation targets (mirrors the minimap's rim behavior).
		f32 half_w = W / 2.0f - marker_size2;
		f32 half_h = H / 2.0f - marker_size2;
		if (half_w > 0 && half_h > 0) {
			f32 dx = sx - W / 2.0f;
			f32 dz = sz - H / 2.0f;
			f32 max_abs = std::max(std::fabs(dx) / half_w,
					std::fabs(dz) / half_h);
			if (max_abs > 1.0f) {
				dx /= max_abs;
				dz /= max_abs;
				sx = W / 2.0f + dx * half_w;
				sz = H / 2.0f + dz * half_h;
			}
		}

		s32 ix = (s32)sx;
		s32 iz = (s32)sz;
		video::SColor col = marker.color;
		col.setAlpha(255);

		// Waypoint dot.
		core::rect<s32> dot_rect(ix - (s32)marker_size2,
				iz - (s32)marker_size2,
				ix + (s32)marker_size2,
				iz + (s32)marker_size2);
		driver->draw2DRectangle(col, dot_rect, nullptr);

		// Waypoint name next to the dot.
		if (font && !marker.label.empty()) {
			core::stringw text = utf8_to_wide(marker.label);
			core::dimension2du dim = font->getDimension(text.c_str());
			core::rect<s32> label_rect(ix + (s32)marker_size2 + 4,
					iz - (s32)dim.Height / 2,
					ix + (s32)marker_size2 + 4 + (s32)dim.Width,
					iz + (s32)dim.Height / 2);
			font->draw(text, label_rect, col);
		}
	}
}

std::string AlBigMap::renderSectionToImage(v3s32 center, v3s32 size)
{
	if (size.X <= 0 || size.Z <= 0 || m_save_dir.empty())
		return "";

	s32 node_min_x = center.X - size.X / 2;
	s32 node_min_z = center.Z - size.Z / 2;
	s32 node_max_x = node_min_x + size.X - 1;
	s32 node_max_z = node_min_z + size.Z - 1;

	// Resolution: one pixel per node, capped so huge sections stay bounded.
	const s32 MAX_OUT = 2048;
	s32 out_w = size.X;
	s32 out_h = size.Z;
	if (out_w > MAX_OUT || out_h > MAX_OUT) {
		float s = std::min((f32)MAX_OUT / out_w, (f32)MAX_OUT / out_h);
		out_w = std::max(1, (s32)(out_w * s));
		out_h = std::max(1, (s32)(out_h * s));
	}

	s32 bx_min = floorDiv(node_min_x, MAP_BLOCKSIZE);
	s32 bx_max = floorDiv(node_max_x, MAP_BLOCKSIZE);
	s32 bz_min = floorDiv(node_min_z, MAP_BLOCKSIZE);
	s32 bz_max = floorDiv(node_max_z, MAP_BLOCKSIZE);

	// Per-column winner (topmost non-air pixel), in node resolution.
	std::vector<s32> best((size_t)size.X * size.Z, -32768);
	std::vector<video::SColor> colors((size_t)size.X * size.Z);

	for (const auto &kv : m_blocks) {
		const v3s16 &bp = kv.first;
		if (bp.X < bx_min || bp.X > bx_max || bp.Z < bz_min || bp.Z > bz_max)
			continue;
		const AlBigMapBlock &block = *kv.second;
		const std::vector<video::SColor> &tile = getTile(block);
		s32 nx0 = bp.X * MAP_BLOCKSIZE;
		s32 nz0 = bp.Z * MAP_BLOCKSIZE;
		for (u8 z = 0; z < MAP_BLOCKSIZE; z++)
		for (u8 x = 0; x < MAP_BLOCKSIZE; x++) {
			size_t idx = z * MAP_BLOCKSIZE + x;
			if (block.pixels[idx].param0 == CONTENT_AIR)
				continue;
			s32 node_x = nx0 + x;
			s32 node_z = nz0 + z;
			s32 bxi = node_x - node_min_x;
			// North-up: larger node_z renders toward the top.
			s32 bzi = node_max_z - node_z;
			if (bxi < 0 || bzi < 0 || bxi >= size.X || bzi >= size.Z)
				continue;
			s32 h_abs = bp.Y * MAP_BLOCKSIZE + block.pixels[idx].height;
			size_t si = bzi * size.X + bxi;
			if (h_abs > best[si]) {
				best[si] = h_abs;
				colors[si] = tile[idx];
			}
		}
	}

	auto *driver = RenderingEngine::get_video_driver();
	if (!driver)
		return "";

	video::IImage *node_image = driver->createImage(video::ECF_A8R8G8B8,
			core::dimension2du(size.X, size.Z));
	if (!node_image)
		return "";
	node_image->fill(video::SColor(90, 0, 0, 0));
	for (s32 j = 0; j < size.Z; j++)
	for (s32 i = 0; i < size.X; i++) {
		size_t si = j * size.X + i;
		if (best[si] > -32768)
			node_image->setPixel(i, j, colors[si]);
	}

	video::IImage *out_image = node_image;
	if (out_w != size.X || out_h != size.Z) {
		out_image = driver->createImage(video::ECF_A8R8G8B8,
				core::dimension2du(out_w, out_h));
		if (!out_image) {
			node_image->drop();
			return "";
		}
		node_image->copyToScaling(out_image);
		node_image->drop();
	}

	fs::CreateAllDirs(getImagesDir());
	std::string base = "albigmap_" + std::to_string(m_image_seq++) + ".png";
	std::string path = getImagesDir() + DIR_DELIM + base;

	bool ok = driver->writeImageToFile(out_image, path.c_str(), 100);
	out_image->drop();
	if (!ok) {
		errorstream << "AlBigMap: failed to write section image " << path
				<< std::endl;
		return "";
	}
	return base;
}

void AlBigMap::clearImages()
{
	std::string dir = getImagesDir();
	if (dir.empty() || !fs::PathExists(dir))
		return;
	for (const auto &entry : fs::GetDirListing(dir)) {
		if (entry.dir)
			continue;
		if (entry.name.rfind("albigmap_", 0) != 0)
			continue;
		fs::DeleteSingleFileOrEmptyDirectory(dir + DIR_DELIM + entry.name, false);
	}
}

core::rect<s32> AlBigMap::followButtonRect(v2u32 target_size)
{
	const s32 W = (s32)target_size.X;
	const s32 w = 150;
	const s32 h = 30;
	const s32 pad = 14;
	return core::rect<s32>(W - pad - w, pad, W - pad, pad + h);
}

void AlBigMap::drawStatusOverlay(video::IVideoDriver *driver, v2u32 target_size)
{
	const s32 W = (s32)target_size.X;
	const s32 H = (s32)target_size.Y;
	if (W <= 0 || H <= 0)
		return;
	gui::IGUIFont *font = g_fontengine ? g_fontengine->getFont() : nullptr;
	if (!font)
		return;

	const video::SColor text_col(255, 230, 230, 230);
	const video::SColor bg(150, 10, 10, 10);

	// Status readout (top-left): center coords, zoom, saved block count.
	char line[96];
	snprintf(line, sizeof(line), "X %d   Z %d", m_center.X, m_center.Y);
	core::stringw l0 = utf8_to_wide(line);
	snprintf(line, sizeof(line), "Zoom: %.1fx", m_zoom);
	core::stringw l1 = utf8_to_wide(line);
	snprintf(line, sizeof(line), "Blocks: %llu",
			(unsigned long long)m_blocks.size());
	core::stringw l2 = utf8_to_wide(line);
	core::stringw lines[3] = { l0, l1, l2 };

	s32 box_w = 12;
	s32 total_h = 12;
	for (int i = 0; i < 3; i++) {
		core::dimension2du d = font->getDimension(lines[i].c_str());
		box_w = std::max(box_w, (s32)d.Width);
		total_h += (s32)d.Height + 3;
	}
	box_w += 28;
	core::rect<s32> box(12, 12, 12 + box_w, 12 + total_h);
	driver->draw2DRectangle(bg, box, nullptr);
	s32 ly = 20;
	for (int i = 0; i < 3; i++) {
		core::dimension2du d = font->getDimension(lines[i].c_str());
		core::rect<s32> r(20, ly, 20 + (s32)d.Width, ly + (s32)d.Height);
		font->draw(lines[i], r, text_col);
		ly += (s32)d.Height + 3;
	}

	// Re-follow button (top-right).
	core::rect<s32> btn = followButtonRect(target_size);
	video::SColor btn_border = m_follow_player
			? video::SColor(255, 80, 255, 120)
			: video::SColor(220, 180, 180, 180);
	video::SColor btn_bg = m_follow_player
			? video::SColor(190, 0, 90, 40)
			: video::SColor(170, 40, 40, 40);
	driver->draw2DRectangle(btn_border, btn, nullptr);
	driver->draw2DRectangle(btn_bg,
			core::rect<s32>(btn.UpperLeftCorner.X + 2, btn.UpperLeftCorner.Y + 2,
					btn.LowerRightCorner.X - 2, btn.LowerRightCorner.Y - 2),
			nullptr);
	core::stringw btext = utf8_to_wide(m_follow_player ? "FOLLOW: on" : "FOLLOW: off");
	core::dimension2du bdim = font->getDimension(btext.c_str());
	core::rect<s32> br(btn.UpperLeftCorner.X + (btn.getWidth() - (s32)bdim.Width) / 2,
			btn.UpperLeftCorner.Y + (btn.getHeight() - (s32)bdim.Height) / 2,
			btn.UpperLeftCorner.X + (btn.getWidth() + (s32)bdim.Width) / 2,
			btn.UpperLeftCorner.Y + (btn.getHeight() + (s32)bdim.Height) / 2);
	font->draw(btext, br, btn_border);

	// First-open control hints (bottom-center), dismissed on interaction.
	if (m_open_time < 6.0f) {
		char hbuf[160];
		snprintf(hbuf, sizeof(hbuf),
				"Drag: pan   Scroll: zoom   Click FOLLOW: recenter   M/ESC: close");
		core::stringw htext = utf8_to_wide(hbuf);
		core::dimension2du hdim = font->getDimension(htext.c_str());
		s32 hw = (s32)hdim.Width + 28;
		s32 hh = (s32)hdim.Height + 12;
		core::rect<s32> hb(W / 2 - hw / 2, H - 52, W / 2 + hw / 2, H - 52 + hh);
		driver->draw2DRectangle(bg, hb, nullptr);
		core::rect<s32> hr(W / 2 - (s32)hdim.Width / 2, H - 46,
				W / 2 + (s32)hdim.Width / 2, H - 46 + (s32)hdim.Height);
		font->draw(htext, hr, text_col);
	}
}
