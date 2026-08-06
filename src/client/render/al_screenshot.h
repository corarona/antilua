// Antilua — scene-only screenshot pipeline step
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "client/render/pipeline.h"
#include <string>

class Client;

namespace video
{
	class IVideoDriver;
}

namespace AlScreenshot {

// Queue a screenshot request. The screenshot is captured on the next
// rendered frame, with all overlays (HUD, chat, debug, cheat menu, ...)
// suppressed. callback_ref is a Lua registry reference (from luaL_ref)
// that will be fired with the saved filename and then released; pass
// LUA_NOREF to skip the callback.
void request(bool scene_only, const std::string &path, int callback_ref);

// Returns true if at least one screenshot request is pending.
bool hasPending();

// Called by AlSceneCapture::run() while a request is pending: captures the
// current back buffer, saves it to disk, fires the Lua callback and returns
// the saved filename (empty string on failure).
std::string capturePending(video::IVideoDriver *driver, Client *client);

} // namespace AlScreenshot

/**
 * Pipeline step that captures a clean screenshot of the 3D scene only.
 *
 * It is inserted right before DrawHUD, so the back buffer it reads has the
 * full scene (map, entities, sky, post-processing) but none of the 2D
 * overlays (HUD, crosshair, formspecs/chat, cheat menu, debug text) that are
 * drawn afterwards — those are excluded from the capture without disturbing
 * the frame the player sees.
 */
class AlSceneCapture : public TrivialRenderStep
{
public:
	virtual void reset(PipelineContext &context) override;
	virtual void run(PipelineContext &context) override;
};
