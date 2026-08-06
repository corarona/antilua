// Antilua — scene-only screenshot pipeline step
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client/render/al_screenshot.h"
#include "client/client.h"
#include "script/scripting_client.h"
#include "util/screenshot.h"
#include "filesys.h"
#include "settings.h"
#include "util/numeric.h"
#include "log.h"
#include "debug.h"
#include <IVideoDriver.h>
#include <IImage.h>

#include <deque>

namespace AlScreenshot {

struct Request
{
	bool scene_only = true;
	std::string path;          // empty = auto-generate via takeScreenshot()
	int callback_ref = LUA_NOREF;
};

static std::deque<Request> g_queue;

void request(bool scene_only, const std::string &path, int callback_ref)
{
	Request req;
	req.scene_only = scene_only;
	req.path = path;
	req.callback_ref = callback_ref;
	g_queue.push_back(std::move(req));
}

bool hasPending()
{
	return !g_queue.empty();
}

static void fireCallback(lua_State *L, const Request &req,
		const std::string &filename)
{
	if (req.callback_ref == LUA_NOREF)
		return;
	if (!L) {
		errorstream << "AlScreenshot: no Lua state to fire callback" << std::endl;
		return;
	}

	lua_rawgeti(L, LUA_REGISTRYINDEX, req.callback_ref);
	lua_pushstring(L, filename.c_str());
	if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
		errorstream << "AlScreenshot: callback error: "
			<< lua_tostring(L, -1) << std::endl;
		lua_pop(L, 1);
	}
	luaL_unref(L, LUA_REGISTRYINDEX, req.callback_ref);
}

// Save a screenshot to an explicit path (mirrors the settings handling of
// takeScreenshot() but keeps util/screenshot.cpp upstream code untouched).
static bool captureToPath(video::IVideoDriver *driver, const std::string &path)
{
	sanity_check(driver);

	video::IImage *raw_image = driver->createScreenShot();
	if (!raw_image) {
		errorstream << "Could not take screenshot" << std::endl;
		return false;
	}

	video::IImage *image = driver->createImage(
			video::ECF_R8G8B8, raw_image->getDimension());
	if (!image) {
		errorstream << "Could not create image for screenshot" << std::endl;
		raw_image->drop();
		return false;
	}

	raw_image->copyTo(image);
	raw_image->drop();

	fs::CreateAllDirs(fs::RemoveLastPathComponent(path));

	u32 quality = (u32)g_settings->getS32("screenshot_quality");
	quality = rangelim(quality, 0, 100) / 100.0f * 255;

	bool success = driver->writeImageToFile(image, path.c_str(), quality);
	image->drop();

	if (success)
		infostream << "Saved screenshot to \"" << path << "\"" << std::endl;
	else
		errorstream << "Failed to save screenshot to \"" << path << "\"" << std::endl;
	return success;
}

std::string capturePending(video::IVideoDriver *driver, Client *client)
{
	if (g_queue.empty())
		return "";

	Request req = std::move(g_queue.front());
	g_queue.pop_front();

	std::string filename;
	if (req.path.empty()) {
		if (!takeScreenshot(driver, filename))
			filename.clear();
	} else if (captureToPath(driver, req.path)) {
		filename = req.path;
	}

	fireCallback(client ? client->getScript()->getLuaState() : nullptr,
			req, filename);
	return filename;
}

} // namespace AlScreenshot

void AlSceneCapture::reset(PipelineContext &context)
{
	if (AlScreenshot::hasPending()) {
		context.scene_only = true;
		context.draw_wield_tool = false;
	}
}

void AlSceneCapture::run(PipelineContext &context)
{
	if (!AlScreenshot::hasPending())
		return;

	AlScreenshot::capturePending(context.device->getVideoDriver(),
			context.client);
}
