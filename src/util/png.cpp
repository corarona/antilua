// Antilua
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2021 hecks
// Rewritten to use libpng for proper filter support

#include "png.h"
#include <string>
#include <vector>
#include <memory>
#include <cstring>
#include <png.h>
#include "irrlichttypes.h"

static int choose_color_type(const u8 *data, u32 width, u32 height,
	std::vector<u8> &converted)
{
	const u32 npixels = width * height;
	bool all_opaque = true;
	bool gray = true;

	for (u32 i = 0; i < npixels; i++) {
		const u8 *p = &data[4*i];
		if (p[3] != 255)
			all_opaque = false;
		if (p[0] != p[1] || p[1] != p[2])
			gray = false;
		if (!all_opaque && !gray)
			return PNG_COLOR_TYPE_RGBA;
	}

	// All opaque. Convert to grayscale or RGB.
	if (gray) {
		converted.resize(width * height);
		for (u32 i = 0; i < npixels; i++)
			converted[i] = data[4*i];
		return PNG_COLOR_TYPE_GRAY;
	}

	converted.resize(width * 3 * height);
	for (u32 i = 0; i < npixels; i++)
		memcpy(&converted[3*i], &data[4*i], 3);
	return PNG_COLOR_TYPE_RGB;
}

std::string encodePNG(const u8 *data, u32 width, u32 height, s32 compression)
{
	// Optimize: reduce color type when possible
	std::vector<u8> converted;
	int color_type = choose_color_type(data, width, height, converted);
	if (!converted.empty())
		data = converted.data();

	// Create write structs
	png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING,
		nullptr, nullptr, nullptr);
	if (!png_ptr)
		return {};

	png_infop info_ptr = png_create_info_struct(png_ptr);
	if (!info_ptr) {
		png_destroy_write_struct(&png_ptr, nullptr);
		return {};
	}

	// Error handler
	if (setjmp(png_jmpbuf(png_ptr))) {
		png_destroy_write_struct(&png_ptr, &info_ptr);
		return {};
	}

	// Write-to-string callback
	struct Sink { std::string buf; } sink;
	png_set_write_fn(png_ptr, &sink, [](png_structp p, png_bytep d, png_size_t l) {
		static_cast<Sink *>(png_get_io_ptr(p))->buf.append(
			reinterpret_cast<const char *>(d), l);
	}, nullptr);

	// Header
	png_set_IHDR(png_ptr, info_ptr, width, height, 8, color_type,
		PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

	// Compression & filters
	if (compression >= 0)
		png_set_compression_level(png_ptr, compression);
	png_set_filter(png_ptr, 0, PNG_ALL_FILTERS);

	png_write_info(png_ptr, info_ptr);

	// Write rows
	u32 bpp = png_get_rowbytes(png_ptr, info_ptr) / width;
	std::vector<png_bytep> rows(height);
	for (u32 y = 0; y < height; y++)
		rows[y] = const_cast<png_bytep>(data + y * width * bpp);

	png_write_image(png_ptr, rows.data());
	png_write_end(png_ptr, info_ptr);
	png_destroy_write_struct(&png_ptr, &info_ptr);

	return std::move(sink.buf);
}
