// Antilua — Task marker store implementation
// SPDX-License-Identifier: LGPL-2.1-or-later

#include <algorithm>
#include "task_markers.h"
#include "client/render/al_draw_shapes.h"

std::vector<TaskNodeMarker> TaskMarkerStore::s_nodes;
std::vector<TaskTracerMarker> TaskMarkerStore::s_tracers;

void TaskMarkerStore::addNode(const v3f &pos, video::SColor color)
{
	s_nodes.push_back({pos, color});
	flush();
}

bool TaskMarkerStore::removeNode(const v3f &pos)
{
	auto it = std::find_if(s_nodes.begin(), s_nodes.end(),
		[&pos](const TaskNodeMarker &n) { return n.position == pos; });
	if (it == s_nodes.end())
		return false;
	s_nodes.erase(it);
	flush();
	return true;
}

void TaskMarkerStore::addTracer(const v3f &start, const v3f &end, video::SColor color)
{
	s_tracers.push_back({start, end, color});
	flush();
}

bool TaskMarkerStore::removeTracer(const v3f &start, const v3f &end)
{
	auto it = std::find_if(s_tracers.begin(), s_tracers.end(),
		[&start, &end](const TaskTracerMarker &t) {
			return t.start == start && t.end == end;
		});
	if (it == s_tracers.end())
		return false;
	s_tracers.erase(it);
	flush();
	return true;
}

void TaskMarkerStore::flush()
{
	DrawLuaShapes::clear(DRAW_GROUP_ID);

	for (const auto &n : s_nodes) {
		DrawShapeCommand cmd;
		cmd.type = DrawShapeCommand::Type::WireBox;
		cmd.pos = n.position - v3f(0.5f, 0.5f, 0.5f);
		cmd.pos2 = n.position + v3f(0.5f, 0.5f, 0.5f);
		cmd.color = n.color;
		cmd.group_id = DRAW_GROUP_ID;
		DrawLuaShapes::addCommand(cmd);
	}

	for (const auto &t : s_tracers) {
		DrawShapeCommand cmd;
		cmd.type = DrawShapeCommand::Type::Line;
		cmd.pos = t.start;
		cmd.pos2 = t.end;
		cmd.color = t.color;
		cmd.group_id = DRAW_GROUP_ID;
		DrawLuaShapes::addCommand(cmd);
	}
}

void TaskMarkerStore::clearAll()
{
	s_nodes.clear();
	s_tracers.clear();
	DrawLuaShapes::clear(DRAW_GROUP_ID);
}
