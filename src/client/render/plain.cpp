// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>
// Copyright (C) 2017 numzero, Lobachevskiy Vitaliy <numzer0@yandex.ru>

#include "plain.h"
#include "secondstage.h"
#include "settings.h"
#include "client/camera.h"
#include "client/client.h"
#include "client/clientenvironment.h"
#include "client/clientmap.h"
#include "client/content_cao.h"
#include "client/hud.h"
#include "client/minimap.h"
#include "client/shadows/dynamicshadowsrender.h"
#include "util/numeric.h"
#include "client/render/al_draw_shapes.h"
#include <ICameraSceneNode.h>
#include <IGUIEnvironment.h>
#include "map.h"
#include "nodedef.h"
#include "gui/cheatMenu.h"
#include "gui/mainmenumanager.h"
#include "client/client.h"
#include <vector>
#include <CMeshBuffer.h>

/// Draw3D pipeline step
void Draw3D::run(PipelineContext &context)
{
	if (m_target)
		m_target->activate(context);

	context.device->getSceneManager()->drawAll();
	context.device->getVideoDriver()->setTransform(video::ETS_WORLD, core::IdentityMatrix);
	if (!context.show_hud)
		return;
	context.hud->drawBlockBounds();
	context.hud->drawSelectionMesh();
}

void DrawTracersAndESP::run(PipelineContext &context)
{
	video::IVideoDriver *driver = context.device->getVideoDriver();

	// Set up material: draw through walls, thicker lines
	video::SMaterial mat;
	mat.ZBuffer = video::ECFN_ALWAYS;
	mat.ZWriteEnable = video::EZW_OFF;
	mat.Thickness = 2.0f;
	driver->setMaterial(mat);

	v3f camera_pos = context.client->getCamera()->getPosition();

	if (g_settings->getBool("enable_entity_esp") || g_settings->getBool("enable_entity_tracers") || g_settings->getBool("enable_entity_wallhack"))
		drawEntityESP(context, camera_pos);

	if (g_settings->getBool("enable_player_esp") || g_settings->getBool("enable_player_tracers") || g_settings->getBool("enable_player_wallhack"))
		drawPlayerESP(context, camera_pos);

	if (g_settings->getBool("enable_node_esp") || g_settings->getBool("enable_node_tracers"))
		drawNodeESP(context, camera_pos);
}

video::SColor DrawTracersAndESP::parseColor(const std::string &setting, u8 alpha)
{
	auto color = g_settings->getV3F(setting);
	if (color.has_value())
		return video::SColor(alpha,
			rangelim((int)color->X, 0, 255),
			rangelim((int)color->Y, 0, 255),
			rangelim((int)color->Z, 0, 255));
	return video::SColor(alpha, 255, 255, 255);
}

bool DrawTracersAndESP::isOccluded(ClientEnvironment &env, v3f from, v3f to)
{
	Map &map = env.getMap();
	v3f dir = to - from;
	float dist = dir.getLength();
	if (dist < 1.0f)
		return false;
	dir /= dist;
	int steps = (int)(dist / BS);
	for (int i = 1; i < steps; i++) {
		v3f check = from + dir * (float)i * BS;
		v3s16 p = floatToInt(check, BS);
		bool pos_ok;
		MapNode n = map.getNode(p, &pos_ok);
		if (pos_ok) {
			const NodeDefManager *ndef = env.getGameDef()->ndef();
			if (ndef && ndef->get(n).walkable && ndef->get(n).name != "ignore" &&
					ndef->get(n).name != "air")
				return true;
		}
	}
	return false;
}

void DrawTracersAndESP::drawWallhackBox(PipelineContext &context, GenericCAO *cao, const v3f &entity_pos,
		const v3f &camera_pos, bool is_player)
{
	ClientEnvironment &env = context.client->getEnv();

	v3s16 offset_s16 = env.getCameraOffset();
	v3f offset_f = intToFloat(offset_s16, BS);
	v3f world_entity_pos = entity_pos + offset_f;
	v3f world_camera_pos = camera_pos + offset_f;

	bool occluded = isOccluded(env, world_camera_pos, world_entity_pos);

	// For occluded entities: render through walls by calling the scene node's
	// own render() with temporarily overridden depth settings.
	// This preserves animations, bone transforms, and hardware skinning.
	if (occluded) {
		scene::ISceneNode *node = cao->getSceneNode();
		if (node) {
			u32 mat_count = node->getMaterialCount();
			std::vector<video::SMaterial> saved_mats(mat_count);
			for (u32 i = 0; i < mat_count; i++) {
				saved_mats[i] = node->getMaterial(i);
				video::SMaterial &mat = node->getMaterial(i);
				mat.ZBuffer = video::ECFN_ALWAYS;
				mat.ZWriteEnable = video::EZW_OFF;
			}
			node->render();
			for (u32 i = 0; i < mat_count; i++)
				node->getMaterial(i) = saved_mats[i];
		}
	}

}

void DrawTracersAndESP::drawEntityESP(PipelineContext &context, const v3f &camera_pos)
{
	ClientEnvironment &env = context.client->getEnv();
	video::IVideoDriver *driver = context.device->getVideoDriver();

	v3s16 offset_s16 = env.getCameraOffset();
	v3f offset_f = intToFloat(offset_s16, BS);
	v3f world_camera_pos = camera_pos + offset_f;

	std::vector<DistanceSortedActiveObject> objects;
	env.getActiveObjects(world_camera_pos, 1000.0f * BS, objects);

	video::SColor esp_color = parseColor("entity_esp_color", 255);
	video::SColor tracer_color = parseColor("entity_esp_color", 200);
	bool show_esp = g_settings->getBool("enable_entity_esp");
	bool show_tracers = g_settings->getBool("enable_entity_tracers");
	bool show_wallhack = g_settings->getBool("enable_entity_wallhack");

	v3f scene_camera_pos = context.client->getCamera()->getCameraNode()->getAbsolutePosition();
	v3f look_dir = context.client->getCamera()->getDirection();
	v3f tracer_origin = scene_camera_pos + look_dir * 0.2f * BS;

	for (auto &obj : objects) {
		GenericCAO *cao = dynamic_cast<GenericCAO *>(obj.obj);
		if (!cao || cao->isPlayer() || cao->isLocalPlayer())
			continue;

		v3f pos = cao->getPosition() - offset_f;

		if (show_wallhack) {
			drawWallhackBox(context, cao, pos, camera_pos, false);
		} else if (show_esp) {
			aabb3f box(v3f(0,0,0), v3f(0,0,0));
			if (cao->getSelectionBox(&box)) {
				box.MinEdge += pos;
				box.MaxEdge += pos;
				driver->draw3DBox(box, esp_color);
			}
		}

		if (show_tracers)
			driver->draw3DLine(tracer_origin, pos, tracer_color);
	}
}

void DrawTracersAndESP::drawPlayerESP(PipelineContext &context, const v3f &camera_pos)
{
	ClientEnvironment &env = context.client->getEnv();
	video::IVideoDriver *driver = context.device->getVideoDriver();

	v3s16 offset_s16 = env.getCameraOffset();
	v3f offset_f = intToFloat(offset_s16, BS);
	v3f world_camera_pos = camera_pos + offset_f;

	std::vector<DistanceSortedActiveObject> objects;
	env.getActiveObjects(world_camera_pos, 1000.0f * BS, objects);

	video::SColor esp_color = parseColor("player_esp_color", 255);
	video::SColor tracer_color = parseColor("player_esp_color", 200);
	bool show_esp = g_settings->getBool("enable_player_esp");
	bool show_tracers = g_settings->getBool("enable_player_tracers");
	bool show_wallhack = g_settings->getBool("enable_player_wallhack");

	v3f scene_camera_pos = context.client->getCamera()->getCameraNode()->getAbsolutePosition();
	v3f look_dir = context.client->getCamera()->getDirection();
	v3f tracer_origin = scene_camera_pos + look_dir * 0.2f * BS;

	for (auto &obj : objects) {
		GenericCAO *cao = dynamic_cast<GenericCAO *>(obj.obj);
		if (!cao || !cao->isPlayer() || cao->isLocalPlayer())
			continue;

		v3f pos = cao->getPosition() - offset_f;

		if (show_wallhack) {
			drawWallhackBox(context, cao, pos, camera_pos, true);
		} else if (show_esp) {
			aabb3f box(v3f(0,0,0), v3f(0,0,0));
			if (cao->getSelectionBox(&box)) {
				box.MinEdge += pos;
				box.MaxEdge += pos;
				driver->draw3DBox(box, esp_color);
			}
		}

		if (show_tracers)
			driver->draw3DLine(tracer_origin, pos, tracer_color);
	}
}

void DrawWield::run(PipelineContext &context)
{
	if (m_target)
		m_target->activate(context);

	if (context.draw_wield_tool)
		context.client->getCamera()->drawWieldedTool();
}

void DrawHUD::run(PipelineContext &context)
{
	if (context.show_hud) {
		if (context.shadow_renderer)
			context.shadow_renderer->drawDebug();

		context.hud->resizeHotbar();

		if (context.draw_crosshair)
			context.hud->drawCrosshair();
	}

	context.hud->drawLuaElements(context.client->getCamera()->getOffset(), !context.show_hud);

	if (context.show_hud) {
		context.client->getCamera()->drawNametags();
	}

	// Draw GUI first (formspecs, chat — under the cheat layer)
	context.device->getGUIEnvironment()->drawAll();

	// Draw cheat menu overlay + panels on top of everything
	if (g_cheat_menu) {
		video::IVideoDriver *driver = context.device->getVideoDriver();
		v2s32 mouse_pos = context.device->getCursorControl()->getPosition();

		if (g_cheat_layer_active) {
			v2u32 ss = driver->getScreenSize();
			driver->draw2DRectangle(video::SColor(178, 0, 0, 0),
				core::rect<s32>(0, 0, ss.X, ss.Y));
			g_cheat_menu->drawSearchBar(driver);
			g_cheat_menu->drawAll(driver, mouse_pos,
				g_show_minimal_debug);
		}
		g_cheat_menu->drawPinned(driver, mouse_pos);

		if (g_cheat_menu->isQuickPaletteActive())
			g_cheat_menu->drawQuickPalette(driver);
	}
}


void MapPostFxStep::setRenderTarget(RenderTarget * _target)
{
	target = _target;
}

void MapPostFxStep::run(PipelineContext &context)
{
	if (target)
		target->activate(context);

	context.client->getEnv().getClientMap().renderPostFx(context.client->getCamera()->getCameraMode());
}

void RenderShadowMapStep::run(PipelineContext &context)
{
	// This is necessary to render shadows for animations correctly
	context.device->getSceneManager()->getRootSceneNode()->OnAnimate(context.device->getTimer()->getTime());
	context.shadow_renderer->update();
}

// class UpscaleStep

void UpscaleStep::run(PipelineContext &context)
{
	video::ITexture *lowres = m_source->getTexture(0);
	m_target->activate(context);
	context.device->getVideoDriver()->draw2DImage(lowres,
			core::rect<s32>(0, 0, context.target_size.X, context.target_size.Y),
			core::rect<s32>(0, 0, lowres->getSize().Width, lowres->getSize().Height));
}

std::unique_ptr<RenderStep> create3DStage(Client *client, v2f scale)
{
	RenderStep *step = new Draw3D();
	if (g_settings->getBool("enable_post_processing")) {
		RenderPipeline *pipeline = new RenderPipeline();
		pipeline->addStep(pipeline->own(std::unique_ptr<RenderStep>(step)));

		auto effect = addPostProcessing(pipeline, step, scale, client);
		effect->setRenderTarget(pipeline->getOutput());
		step = pipeline;
	}
	return std::unique_ptr<RenderStep>(step);
}

static v2f getDownscaleFactor()
{
	u16 undersampling = MYMAX(g_settings->getU16("undersampling"), 1);
	return v2f(1.0f / undersampling);
}

RenderStep* addUpscaling(RenderPipeline *pipeline, RenderStep *previousStep, v2f downscale_factor, Client *client)
{
	const int TEXTURE_LOWRES_COLOR = 0;
	const int TEXTURE_LOWRES_DEPTH = 1;

	if (downscale_factor.X == 1.0f && downscale_factor.Y == 1.0f)
		return previousStep;

	// post-processing pipeline takes care of rescaling
	if (g_settings->getBool("enable_post_processing"))
		return previousStep;

	auto driver = client->getSceneManager()->getVideoDriver();
	video::ECOLOR_FORMAT color_format = selectColorFormat(driver);
	video::ECOLOR_FORMAT depth_format = selectDepthFormat(driver);

	// Initialize buffer
	TextureBuffer *buffer = pipeline->createOwned<TextureBuffer>();
	buffer->setTexture(TEXTURE_LOWRES_COLOR, downscale_factor, "lowres_color", color_format);
	buffer->setTexture(TEXTURE_LOWRES_DEPTH, downscale_factor, "lowres_depth", depth_format);

	// Attach previous step to the buffer
	TextureBufferOutput *buffer_output = pipeline->createOwned<TextureBufferOutput>(
			buffer, std::vector<u8> {TEXTURE_LOWRES_COLOR}, TEXTURE_LOWRES_DEPTH);
	previousStep->setRenderTarget(buffer_output);

	// Add upscaling step
	RenderStep *upscale = pipeline->createOwned<UpscaleStep>();
	upscale->setRenderSource(buffer);
	pipeline->addStep(upscale);

	return upscale;
}

// Build a colored cube mesh buffer for a node-sized box
static void buildNodeBoxMesh(scene::SMeshBuffer *buf, v3f center, video::SColor color)
{
	static const float hbs = BS / 2.0f;
	static const v3f verts[8] = {
		v3f(-hbs, -hbs, -hbs), v3f( hbs, -hbs, -hbs),
		v3f(-hbs,  hbs, -hbs), v3f( hbs,  hbs, -hbs),
		v3f(-hbs, -hbs,  hbs), v3f( hbs, -hbs,  hbs),
		v3f(-hbs,  hbs,  hbs), v3f( hbs,  hbs,  hbs),
	};
	static const int faces[6][4] = {
		{0, 1, 2, 3}, {4, 5, 6, 7}, {1, 5, 3, 7},
		{0, 4, 2, 6}, {2, 3, 6, 7}, {0, 1, 4, 5},
	};
	static const v3f norms[6] = {
		v3f( 0,  0, -1), v3f( 0,  0,  1), v3f( 1,  0,  0),
		v3f(-1,  0,  0), v3f( 0,  1,  0), v3f( 0, -1,  0),
	};

	video::S3DVertex vb[24];
	u16 ib[36];
	u32 vi = 0, ii = 0;
	for (int f = 0; f < 6; f++) {
		for (int j = 0; j < 4; j++) {
			int idx = faces[f][j];
			vb[vi].Pos = center + verts[idx];
			vb[vi].Normal = norms[f];
			vb[vi].Color = color;
			vi++;
		}
		ib[ii++] = vi - 4; ib[ii++] = vi - 3; ib[ii++] = vi - 2;
		ib[ii++] = vi - 2; ib[ii++] = vi - 3; ib[ii++] = vi - 1;
	}
	buf->append(vb, 24, ib, 36);
}

void DrawTracersAndESP::drawNodeBox(video::IVideoDriver *driver, v3f center, video::SColor color)
{
	scene::SMeshBuffer buf;
	buildNodeBoxMesh(&buf, center, color);
	driver->drawMeshBuffer(&buf);
}

void DrawTracersAndESP::drawNodeESP(PipelineContext &context, const v3f &camera_pos)
{
	ClientEnvironment &env = context.client->getEnv();
	video::IVideoDriver *driver = context.device->getVideoDriver();
	ClientMap &map = context.client->getEnv().getClientMap();
	const NodeDefManager *ndef = context.client->getNodeDefManager();

	const auto &node_list = context.client->getNodeEspList();
	if (node_list.empty())
		return;

	bool show_esp = g_settings->getBool("enable_node_esp");
	bool show_tracers = g_settings->getBool("enable_node_tracers");

	v3s16 offset_s16 = env.getCameraOffset();
	v3f offset_f = intToFloat(offset_s16, BS);
	v3f world_camera_pos = camera_pos + offset_f;

	auto esp_opt = g_settings->getV3F("node_esp_color");
	v3f esp_col = esp_opt.value_or(v3f(255, 255, 0));
	u32 esp_alpha = g_settings->getU32("node_esp_alpha");
	video::SColor fill_color(esp_alpha, esp_col.X, esp_col.Y, esp_col.Z);
	video::SColor outline_color(255, esp_col.X, esp_col.Y, esp_col.Z);

	auto tracer_opt = g_settings->getV3F("node_tracers_color");
	v3f tracer_col = tracer_opt.value_or(v3f(255, 255, 0));
	video::SColor tracer_color(200, tracer_col.X, tracer_col.Y, tracer_col.Z);

	// Set up material for through-walls filled rendering
	video::SMaterial fill_mat;
	fill_mat.ZBuffer = video::ECFN_ALWAYS;
	fill_mat.ZWriteEnable = video::EZW_OFF;
	fill_mat.MaterialType = video::EMT_TRANSPARENT_ALPHA_CHANNEL;
	fill_mat.BackfaceCulling = false;

	// Set up material for wireframe outline
	video::SMaterial box_mat;
	box_mat.ZBuffer = video::ECFN_ALWAYS;
	box_mat.ZWriteEnable = video::EZW_OFF;
	box_mat.Thickness = 2.0f;

	// Camera position in world node coordinates (with camera offset)
	v3s16 cam_pos = floatToInt(world_camera_pos, BS);
	v3s16 blocks_min, blocks_max;
	map.getBlocksInViewRange(cam_pos, &blocks_min, &blocks_max);
	int total_matches = 0;
	for (s16 bz = blocks_min.Z; bz <= blocks_max.Z; bz++)
	for (s16 by = blocks_min.Y; by <= blocks_max.Y; by++)
	for (s16 bx = blocks_min.X; bx <= blocks_max.X; bx++) {
		MapBlock *block = map.getBlockNoCreateNoEx(v3s16(bx, by, bz));
		if (!block)
			continue;
		v3s16 base = block->getPosRelative();
		for (s16 nz = 0; nz < MAP_BLOCKSIZE; nz++)
		for (s16 ny = 0; ny < MAP_BLOCKSIZE; ny++)
		for (s16 nx = 0; nx < MAP_BLOCKSIZE; nx++) {
			v3s16 p = base + v3s16(nx, ny, nz);
			MapNode n = map.getNode(p);
			const std::string &node_name = ndef->get(n).name;
			if (node_list.find(node_name) == node_list.end())
				continue;
			total_matches++;

			v3f pos = intToFloat(p, BS) - offset_f;

			if (show_esp) {
				driver->setMaterial(fill_mat);
				drawNodeBox(driver, pos, fill_color);
				driver->setMaterial(box_mat);
				aabb3f box(pos - v3f(BS/2.0f), pos + v3f(BS/2.0f));
				driver->draw3DBox(box, outline_color);
			}
			if (show_tracers)
				driver->draw3DLine(camera_pos, pos, tracer_color);
		}
	}
}

void populatePlainPipeline(RenderPipeline *pipeline, Client *client)
{
	auto downscale_factor = getDownscaleFactor();
	auto step3D = pipeline->own(create3DStage(client, downscale_factor));
	pipeline->addStep(step3D);
	pipeline->addStep<DrawTracersAndESP>();
	pipeline->addStep<DrawLuaShapes>();
	pipeline->addStep<DrawWield>();
	pipeline->addStep<MapPostFxStep>();

	step3D = addUpscaling(pipeline, step3D, downscale_factor, client);

	step3D->setRenderTarget(pipeline->createOwned<ScreenTarget>());

	pipeline->addStep<DrawHUD>();
}

video::ECOLOR_FORMAT selectColorFormat(video::IVideoDriver *driver)
{
	u32 bits = g_settings->getU32("post_processing_texture_bits");
	if (bits >= 16 && driver->queryTextureFormat(video::ECF_A16B16G16R16F) &&
		driver->queryFeature(video::EVDF_RENDER_TO_FLOAT_TEXTURE))
		return video::ECF_A16B16G16R16F;
	if (bits >= 10 && driver->queryTextureFormat(video::ECF_A2R10G10B10))
		return video::ECF_A2R10G10B10;
	return video::ECF_A8R8G8B8;
}

video::ECOLOR_FORMAT selectDepthFormat(video::IVideoDriver *driver)
{
	if (driver->queryTextureFormat(video::ECF_D24))
		return video::ECF_D24;
	if (driver->queryTextureFormat(video::ECF_D24S8))
		return video::ECF_D24S8;
	return video::ECF_D16; // fallback depth format
}
