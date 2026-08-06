// Antilua — big map fullscreen overlay render step
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "client/render/pipeline.h"

/**
 * Pipeline step that draws the Antilua big map (from AlBigMap) fullscreen,
 * on top of the HUD. Does nothing when the map is closed.
 *
 * Registered as the last step of the active render pipeline so it covers
 * everything. See AlBigMap::draw().
 */
class AlBigMapOverlay : public TrivialRenderStep
{
public:
	virtual void run(PipelineContext &context) override;
};
