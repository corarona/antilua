// Antilua — Lua 3D drawing API pipeline step
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "client/render/al_draw_shapes.h"
#include "client/client.h"
#include "client/clientenvironment.h"
#include "client/camera.h"
#include "client/mesh.h"
#include "settings.h"
#include <IVideoDriver.h>
#include <CMeshBuffer.h>
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

// --- Surface mesh sphere ---
static void buildSphereMesh(scene::SMeshBuffer *buf, v3f center, f32 radius,
		video::SColor color, u32 segments)
{
	u32 rings = segments / 2;
	if (rings < 2) rings = 2;

	u32 vertCount = (rings + 1) * (segments + 1);
	u32 triCount = rings * segments * 2;

	std::vector<video::S3DVertex> verts(vertCount);
	std::vector<u16> idx(triCount * 3);

	u32 vi = 0;
	for (u32 lat = 0; lat <= rings; lat++) {
		f32 theta = (f32)lat / rings * M_PI;
		f32 sinTheta = std::sin(theta);
		f32 cosTheta = std::cos(theta);
		for (u32 lon = 0; lon <= segments; lon++) {
			f32 phi = (f32)lon / segments * 2.0f * M_PI;
			video::S3DVertex &v = verts[vi++];
			v.Pos = v3f(
				center.X + sinTheta * std::cos(phi) * radius,
				center.Y + cosTheta * radius,
				center.Z + sinTheta * std::sin(phi) * radius);
			v.Normal = v3f(
				sinTheta * std::cos(phi),
				cosTheta,
				sinTheta * std::sin(phi));
			v.Color = color;
		}
	}

	u32 ii = 0;
	for (u32 lat = 0; lat < rings; lat++) {
		for (u32 lon = 0; lon < segments; lon++) {
			u16 a = lat * (segments + 1) + lon;
			u16 b = a + segments + 1;
			idx[ii++] = a;     idx[ii++] = b;     idx[ii++] = a + 1;
			idx[ii++] = a + 1; idx[ii++] = b;     idx[ii++] = b + 1;
		}
	}

	buf->append(verts.data(), vertCount, idx.data(), triCount * 3);
}

// --- Surface mesh box ---
static void buildBoxMesh(scene::SMeshBuffer *buf,
		v3f minp, v3f maxp, video::SColor color)
{
	static const int quad_indices[6][4] = {
		{0, 1, 2, 3},  {4, 5, 6, 7},  {1, 5, 3, 7},
		{0, 4, 2, 6},  {2, 3, 6, 7},  {0, 1, 4, 5},
	};
	static const v3f base_verts[8] = {
		v3f(-1, -1, -1), v3f( 1, -1, -1),
		v3f(-1,  1, -1), v3f( 1,  1, -1),
		v3f(-1, -1,  1), v3f( 1, -1,  1),
		v3f(-1,  1,  1), v3f( 1,  1,  1),
	};
	static const v3f face_normals[6] = {
		v3f( 0,  0, -1),  // front
		v3f( 0,  0,  1),  // back
		v3f( 1,  0,  0),  // right
		v3f(-1,  0,  0),  // left
		v3f( 0,  1,  0),  // top
		v3f( 0, -1,  0),  // bottom
	};
	v3f scale = (maxp - minp) * 0.5f;
	v3f center = (minp + maxp) * 0.5f;

	video::S3DVertex vb[24];
	u16 ib[36];
	u32 vi = 0;
	u32 ii = 0;
	for (int face = 0; face < 6; face++) {
		for (int j = 0; j < 4; j++) {
			int idx = quad_indices[face][j];
			vb[vi].Pos = v3f(
				center.X + base_verts[idx].X * scale.X,
				center.Y + base_verts[idx].Y * scale.Y,
				center.Z + base_verts[idx].Z * scale.Z);
			vb[vi].Normal = face_normals[face];
			vb[vi].Color = color;
			vi++;
		}
		ib[ii++] = vi - 4; ib[ii++] = vi - 3; ib[ii++] = vi - 2;
		ib[ii++] = vi - 2; ib[ii++] = vi - 3; ib[ii++] = vi - 1;
	}
	buf->append(vb, 24, ib, 36);
}

// --- Wireframe sphere (lat/long lines) ---
static void drawWireSphere(video::IVideoDriver *driver, v3f center, f32 radius,
		video::SColor color, u32 segments)
{
	// Debug: axis cross at radius distance (verify scale)
	video::SColor dbg(255, 0, 255, 255);
	for (int d = 1; d >= -1; d -= 2) {
		driver->draw3DLine(center, v3f(center.X + radius * d, center.Y, center.Z), dbg);
		driver->draw3DLine(center, v3f(center.X, center.Y + radius * d, center.Z), dbg);
		driver->draw3DLine(center, v3f(center.X, center.Y, center.Z + radius * d), dbg);
	}

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

			driver->draw3DLine(v3f(center.X + x1, center.Y + y1, center.Z + z1),
				v3f(center.X + x2, center.Y + y2, center.Z + z2), color);
			driver->draw3DLine(v3f(center.X + x1, center.Y + y1, center.Z + z1),
				v3f(center.X + x3, center.Y + y3, center.Z + z3), color);
		}
	}
}

// --- Wireframe circle ---
static void drawWireCircle(video::IVideoDriver *driver, v3f center, f32 radius,
		video::SColor color, u32 segments)
{
	if (segments < 3) segments = 3;
	for (u32 i = 0; i < segments; i++) {
		f32 a1 = (f32)i / segments * 2.0f * M_PI;
		f32 a2 = (f32)(i + 1) / segments * 2.0f * M_PI;
		driver->draw3DLine(
			v3f(center.X + std::cos(a1) * radius, center.Y,
				center.Z + std::sin(a1) * radius),
			v3f(center.X + std::cos(a2) * radius, center.Y,
				center.Z + std::sin(a2) * radius),
			color);
	}
}

void DrawLuaShapes::run(PipelineContext &context)
{
	if (s_commands.empty() || context.scene_only)
		return;

	video::IVideoDriver *driver = context.device->getVideoDriver();

	video::SMaterial mat;
	mat.ZBuffer = video::ECFN_ALWAYS;
	mat.ZWriteEnable = video::EZW_OFF;
	mat.Thickness = 2.0f;
	mat.BackfaceCulling = false;

	v3f offset_f = intToFloat(
		context.client->getEnv().getCameraOffset(), BS);

	for (const auto &cmd : s_commands) {
		v3f rp = cmd.pos - offset_f;
		v3f rp2 = cmd.pos2 - offset_f;
		video::SColor c = cmd.color;

		switch (cmd.type) {
		case DrawShapeCommand::Type::Sphere:
			if (cmd.wireframe) {
				mat.MaterialType = video::EMT_SOLID;
				driver->setMaterial(mat);
				drawWireSphere(driver, rp, cmd.radius, c, cmd.segments);
			} else {
				bool alpha = c.getAlpha() < 255;
				mat.MaterialType = alpha ? video::EMT_TRANSPARENT_ALPHA_CHANNEL
					: video::EMT_SOLID;
				driver->setMaterial(mat);
				scene::SMeshBuffer meshBuf;
				buildSphereMesh(&meshBuf, rp, cmd.radius, c, cmd.segments);
				colorizeMeshBuffer(&meshBuf, c, 0.5f, v3f(-1, -1, -1));
				driver->drawMeshBuffer(&meshBuf);
			}
			break;

		case DrawShapeCommand::Type::Box:
			if (cmd.wireframe) {
				mat.MaterialType = video::EMT_SOLID;
				driver->setMaterial(mat);
				driver->draw3DBox(core::aabbox3df(rp, rp2), c);
			} else {
				bool alpha = c.getAlpha() < 255;
				mat.MaterialType = alpha ? video::EMT_TRANSPARENT_ALPHA_CHANNEL
					: video::EMT_SOLID;
				driver->setMaterial(mat);
				scene::SMeshBuffer meshBuf;
				buildBoxMesh(&meshBuf, rp, rp2, c);
				colorizeMeshBuffer(&meshBuf, c, 0.5f, v3f(-1, -1, -1));
				driver->drawMeshBuffer(&meshBuf);
			}
			break;

		case DrawShapeCommand::Type::WireBox:
			mat.MaterialType = video::EMT_SOLID;
			driver->setMaterial(mat);
			driver->draw3DBox(core::aabbox3df(rp, rp2), c);
			break;

		case DrawShapeCommand::Type::Line:
			mat.MaterialType = video::EMT_SOLID;
			driver->setMaterial(mat);
			driver->draw3DLine(rp, rp2, c);
			break;

		case DrawShapeCommand::Type::Circle:
			mat.MaterialType = video::EMT_SOLID;
			driver->setMaterial(mat);
			drawWireCircle(driver, rp, cmd.radius, c, cmd.segments);
			break;
		}
	}
}
