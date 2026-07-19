// Antilua — Lua 3D drawing API pipeline step
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client/render/al_draw_shapes.h"
#include "client/client.h"
#include "client/clientenvironment.h"
#include "client/camera.h"
#include "settings.h"
#include <IVideoDriver.h>
#include <cmath>

std::vector<DrawShapeCommand> DrawLuaShapes::s_commands;

void DrawLuaShapes::addCommand(const DrawShapeCommand &cmd)
{
	s_commands.push_back(cmd);
}

void DrawLuaShapes::clear(s32 group_id)
{
	if (group_id < 0) {
		s_commands.clear();
		return;
	}
	auto it = s_commands.begin();
	while (it != s_commands.end()) {
		if (it->group_id == group_id)
			it = s_commands.erase(it);
		else
			++it;
	}
}

static void drawWireSphere(video::IVideoDriver *driver, v3f center, f32 radius,
		video::SColor color, u32 segments)
{
	if (segments < 3) segments = 3;
	u32 rings = segments / 2;
	if (rings < 2) rings = 2;

	for (u32 lat = 0; lat < rings; lat++) {
		f32 theta1 = (f32)lat / rings * M_PI;
		f32 theta2 = (f32)(lat + 1) / rings * M_PI;
		for (u32 lon = 0; lon < segments; lon++) {
			f32 phi1 = (f32)lon / segments * 2.0f * M_PI;
			f32 phi2 = (f32)(lon + 1) / segments * 2.0f * M_PI;

			f32 x1 = std::sin(theta1) * std::cos(phi1) * radius;
			f32 y1 = std::cos(theta1) * radius;
			f32 z1 = std::sin(theta1) * std::sin(phi1) * radius;

			f32 x2 = std::sin(theta1) * std::cos(phi2) * radius;
			f32 y2 = std::cos(theta1) * radius;
			f32 z2 = std::sin(theta1) * std::sin(phi2) * radius;

			f32 x3 = std::sin(theta2) * std::cos(phi1) * radius;
			f32 y3 = std::cos(theta2) * radius;
			f32 z3 = std::sin(theta2) * std::sin(phi1) * radius;

			driver->draw3DLine(
				v3f(center.X + x1, center.Y + y1, center.Z + z1),
				v3f(center.X + x2, center.Y + y2, center.Z + z2),
				color);

			driver->draw3DLine(
				v3f(center.X + x1, center.Y + y1, center.Z + z1),
				v3f(center.X + x3, center.Y + y3, center.Z + z3),
				color);
		}
	}
}

static void drawWireCircle(video::IVideoDriver *driver, v3f center, f32 radius,
		video::SColor color, u32 segments)
{
	if (segments < 3) segments = 3;
	for (u32 i = 0; i < segments; i++) {
		f32 a1 = (f32)i / segments * 2.0f * M_PI;
		f32 a2 = (f32)(i + 1) / segments * 2.0f * M_PI;
		driver->draw3DLine(
			v3f(center.X + std::cos(a1) * radius, center.Y, center.Z + std::sin(a1) * radius),
			v3f(center.X + std::cos(a2) * radius, center.Y, center.Z + std::sin(a2) * radius),
			color);
	}
}

void DrawLuaShapes::run(PipelineContext &context)
{
	if (s_commands.empty())
		return;

	video::IVideoDriver *driver = context.device->getVideoDriver();

	video::SMaterial mat;
	mat.ZBuffer = video::ECFN_ALWAYS;
	mat.ZWriteEnable = video::EZW_OFF;
	mat.Thickness = 2.0f;
	driver->setMaterial(mat);

	v3f offset_f = intToFloat(
		context.client->getEnv().getCameraOffset(), BS);

	for (const auto &cmd : s_commands) {
		v3f render_pos = cmd.pos - offset_f;
		v3f render_pos2 = cmd.pos2 - offset_f;
		video::SColor c = cmd.color;

		switch (cmd.type) {
		case DrawShapeCommand::Type::Sphere:
			drawWireSphere(driver, render_pos, cmd.radius, c, cmd.segments);
			break;
		case DrawShapeCommand::Type::Box:
			driver->draw3DBox(core::aabbox3df(render_pos, render_pos2), c);
			break;
		case DrawShapeCommand::Type::WireBox:
			driver->draw3DBox(core::aabbox3df(render_pos, render_pos2), c);
			break;
		case DrawShapeCommand::Type::Line:
			driver->draw3DLine(render_pos, render_pos2, c);
			break;
		case DrawShapeCommand::Type::Circle:
			drawWireCircle(driver, render_pos, cmd.radius, c, cmd.segments);
			break;
		}
	}
}
