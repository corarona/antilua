local raily=-28946

local function get_node(pos)
	if pos.y==raily then
		return n_rails
	elseif pos.y==raily-1 then
		return n_base
	elseif pos.y==raily+1 then
		return "air"
	end	
end
