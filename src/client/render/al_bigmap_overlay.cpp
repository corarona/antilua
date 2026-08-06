// Antilua — big map fullscreen overlay render step
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client/render/al_bigmap_overlay.h"
#include "client/al_bigmap.h"
#include "client/client.h"

void AlBigMapOverlay::run(PipelineContext &context)
{
	AlBigMap *bigmap = context.client->getAlBigMap();
	if (!bigmap || !bigmap->isOpen())
		return;
	bigmap->draw(context.device->getVideoDriver(), context.target_size);
}
