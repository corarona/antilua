local shapes = {}

function shapes.generate_cube(w, h, d, mat, hollow)
	local nodes = {}
	for x = 0, w - 1 do
		for y = 0, h - 1 do
			for z = 0, d - 1 do
				if not hollow or x == 0 or x == w - 1 or y == 0 or y == h - 1 or z == 0 or z == d - 1 then
					nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
				end
			end
		end
	end
	return nodes
end

function shapes.generate_sphere(r, mat, hollow)
	local nodes = {}
	local r2 = r * r
	if not hollow then
		for x = -r, r do
			for y = -r, r do
				for z = -r, r do
					if x * x + y * y + z * z <= r2 then
						nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
					end
				end
			end
		end
	else
		for x = -r, r do
			for y = -r, r do
				for z = -r, r do
					local d2 = x * x + y * y + z * z
					if d2 <= r2 then
						if (x+1)*(x+1)+y*y+z*z > r2
							or (x-1)*(x-1)+y*y+z*z > r2
							or x*x+(y+1)*(y+1)+z*z > r2
							or x*x+(y-1)*(y-1)+z*z > r2
							or x*x+y*y+(z+1)*(z+1) > r2
							or x*x+y*y+(z-1)*(z-1) > r2 then
							nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
						end
					end
				end
			end
		end
	end
	return nodes
end

function shapes.generate_circle(r, mat)
	local nodes = {}
	local r2 = r * r
	for x = -r, r do
		for z = -r, r do
			if x * x + z * z <= r2 then
				nodes[#nodes + 1] = {x = x, y = 0, z = z, name = mat}
			end
		end
	end
	return nodes
end

function shapes.generate_ellipsoid(rx, ry, rz, mat, hollow)
	local nodes = {}
	local rx2 = rx * rx
	local ry2 = ry * ry
	local rz2 = rz * rz
	if not hollow then
		for x = -rx, rx do
			for y = -ry, ry do
				for z = -rz, rz do
					if (x*x)/rx2 + (y*y)/ry2 + (z*z)/rz2 <= 1 then
						nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
					end
				end
			end
		end
	else
		for x = -rx, rx do
			for y = -ry, ry do
				for z = -rz, rz do
					local val = (x*x)/rx2 + (y*y)/ry2 + (z*z)/rz2
					if val <= 1 then
						if ((x+1)*(x+1))/rx2 + (y*y)/ry2 + (z*z)/rz2 > 1
							or ((x-1)*(x-1))/rx2 + (y*y)/ry2 + (z*z)/rz2 > 1
							or (x*x)/rx2 + ((y+1)*(y+1))/ry2 + (z*z)/rz2 > 1
							or (x*x)/rx2 + ((y-1)*(y-1))/ry2 + (z*z)/rz2 > 1
							or (x*x)/rx2 + (y*y)/ry2 + ((z+1)*(z+1))/rz2 > 1
							or (x*x)/rx2 + (y*y)/ry2 + ((z-1)*(z-1))/rz2 > 1 then
							nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
						end
					end
				end
			end
		end
	end
	return nodes
end

function shapes.generate_pyramid(base_w, height, mat, hollow)
	local nodes = {}
	for y = 0, height - 1 do
		local w = base_w - 2 * y
		if w <= 0 then break end
		local half = w / 2
		local x1 = math.floor(-half + 0.5)
		local x2 = math.floor(half - 0.5)
		for x = x1, x2 do
			for z = x1, x2 do
				if not hollow or y == 0 or x == x1 or x == x2 or z == x1 or z == x2 then
					nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
				end
			end
		end
	end
	return nodes
end

function shapes.generate_cylinder(r, height, mat, hollow)
	local nodes = {}
	local r2 = r * r
	for y = 0, height - 1 do
		for x = -r, r do
			for z = -r, r do
				local d2 = x * x + z * z
				if d2 <= r2 then
					if not hollow then
						nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
					elseif y == 0 or y == height - 1 or d2 >= (r - 1) * (r - 1) then
						nodes[#nodes + 1] = {x = x, y = y, z = z, name = mat, param2 = 0}
					end
				end
			end
		end
	end
	return nodes
end

schembuilder.generate_shape = function(shape_type, dim_x, dim_y, dim_z, mat, hollow)
	local generators = {
		cube = shapes.generate_cube,
		sphere = shapes.generate_sphere,
		circle = shapes.generate_circle,
		ellipse = shapes.generate_ellipsoid,
		ellipsoid = shapes.generate_ellipsoid,
		pyramid = shapes.generate_pyramid,
		cylinder = shapes.generate_cylinder,
	}
	local gen = generators[shape_type]
	if not gen then return nil, "Unknown shape: " .. tostring(shape_type) end

	local func_map = {
		cube = function() return gen(dim_x, dim_y, dim_z, mat, hollow) end,
		sphere = function() return gen(dim_x, mat, hollow) end,
		circle = function() return gen(dim_x, mat) end,
		ellipse = function() return gen(dim_x, dim_y, dim_z, mat, hollow) end,
		pyramid = function() return gen(dim_x, dim_y, mat, hollow) end,
		cylinder = function() return gen(dim_x, dim_y, mat, hollow) end,
	}
	local fn = func_map[shape_type]
	if not fn then return nil, "No parameter mapping for shape: " .. tostring(shape_type) end
	return fn()
end
