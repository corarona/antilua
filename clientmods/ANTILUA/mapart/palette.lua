-- sRGB gamma to linear
local function srgb_to_linear(c)
	c = c / 255
	if c <= 0.04045 then
		return c / 12.92
	end
	return ((c + 0.055) / 1.055) ^ 2.4
end

-- Find closest palette entry (RGB Euclidean distance)
local function find_closest(r, g, b, use_gamma, pal_override)
	local pal = pal_override or mapart.palette
	local best_idx, best_dist = nil, math.huge
	for i, entry in ipairs(pal) do
		local dr, dg, db
		if use_gamma then
			dr = srgb_to_linear(r) - srgb_to_linear(entry.r)
			dg = srgb_to_linear(g) - srgb_to_linear(entry.g)
			db = srgb_to_linear(b) - srgb_to_linear(entry.b)
		else
			dr = r - entry.r
			dg = g - entry.g
			db = b - entry.b
		end
		local dist = dr*dr + dg*dg + db*db
		if dist < best_dist then
			best_dist = dist
			best_idx = i
		end
		if dist == 0 then break end
	end
	return pal[best_idx]
end

-- Floyd-Steinberg dithering
local function floyd_steinberg(errors, w, h, x, y, dr, dg, db)
	local function add_err(ox, oy, factor)
		local ex, ey = x + ox, y + oy
		if ex >= 0 and ex < w and ey >= 0 and ey < h then
			local idx = ey * w + ex
			errors[idx * 3 + 1] = errors[idx * 3 + 1] + dr * factor
			errors[idx * 3 + 2] = errors[idx * 3 + 2] + dg * factor
			errors[idx * 3 + 3] = errors[idx * 3 + 3] + db * factor
		end
	end
	add_err(1, 0, 7/16)
	add_err(-1, 1, 3/16)
	add_err(0, 1, 5/16)
	add_err(1, 1, 1/16)
end

-- Sample a pixel from the source image (nearest-neighbor or bilinear)
local function sample_px(data, sw, sh, px, py, dw, dh, bilinear)
	if bilinear then
		local sx = px * sw / dw
		local sy = py * sh / dh
		local x1 = math.min(math.floor(sx), sw - 1)
		local y1 = math.min(math.floor(sy), sh - 1)
		local x2 = math.min(x1 + 1, sw - 1)
		local y2 = math.min(y1 + 1, sh - 1)
		local fx = sx - x1; local fy = sy - y1
		local function get(x, y)
			local idx = (y * sw + x) * 4 + 1
			return string.byte(data, idx), string.byte(data, idx + 1),
				string.byte(data, idx + 2), string.byte(data, idx + 3)
		end
		local r1,g1,b1,a1 = get(x1, y1)
		local r2,g2,b2,a2 = get(x2, y1)
		local r3,g3,b3,a3 = get(x1, y2)
		local r4,g4,b4,a4 = get(x2, y2)
		return (1-fx)*(1-fy)*r1 + fx*(1-fy)*r2 + (1-fx)*fy*r3 + fx*fy*r4,
			(1-fx)*(1-fy)*g1 + fx*(1-fy)*g2 + (1-fx)*fy*g3 + fx*fy*g4,
			(1-fx)*(1-fy)*b1 + fx*(1-fy)*b2 + (1-fx)*fy*b3 + fx*fy*b4,
			(1-fx)*(1-fy)*a1 + fx*(1-fy)*a2 + (1-fx)*fy*a3 + fx*fy*a4
	end
	local sx = math.floor(px * sw / dw)
	local sy = math.floor(py * sh / dh)
	sx = math.min(sx, sw - 1); sy = math.min(sy, sh - 1)
	local idx = (sy * sw + sx) * 4 + 1
	return string.byte(data, idx), string.byte(data, idx + 1),
		string.byte(data, idx + 2), string.byte(data, idx + 3)
end
