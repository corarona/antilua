// Antilua — Lua 3D drawing API pipeline step
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <vector>
#include <string>
#include "irr_v3d.h"
#include "SColor.h"
#include "client/render/pipeline.h"

struct DrawShapeCommand
{
	enum class Type {
		Sphere,
		Box,
		WireBox,
		Line,
		Circle,
	};

	Type type;
	v3f pos;
	v3f pos2;
	f32 radius;
	video::SColor color;
	u32 segments;
	s32 group_id;
};

class DrawLuaShapes : public TrivialRenderStep
{
public:
	static void addCommand(const DrawShapeCommand &cmd);
	static void clear(s32 group_id = -1);

	virtual void run(PipelineContext &context) override;

private:
	static std::vector<DrawShapeCommand> s_commands;
};
