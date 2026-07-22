// Antilua — Task marker store for client-side automation visuals
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <vector>
#include "irr_v3d.h"
#include "SColor.h"

struct TaskNodeMarker {
	v3f position;
	video::SColor color;
};

struct TaskTracerMarker {
	v3f start;
	v3f end;
	video::SColor color;
};

class TaskMarkerStore {
public:
	static const s32 DRAW_GROUP_ID = -2;

	static void addNode(const v3f &pos, video::SColor color);
	static bool removeNode(const v3f &pos);

	static void addTracer(const v3f &start, const v3f &end, video::SColor color);
	static bool removeTracer(const v3f &start, const v3f &end);

	static void flush();
	static void clearAll();

private:
	static std::vector<TaskNodeMarker> s_nodes;
	static std::vector<TaskTracerMarker> s_tracers;
};
